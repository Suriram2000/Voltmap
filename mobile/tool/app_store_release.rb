# Explicit release actions using the existing App Store upload credentials.
# Never print private keys, tokens, reviewer credentials, or contact details.
require 'base64'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

APP_ID = '6801616483'.freeze
API_ROOT = 'https://api.appstoreconnect.apple.com'.freeze
VERSION = '1.15.8'.freeze
BUILD = '39'.freeze
ACTION = ENV.fetch('APP_STORE_ACTION', 'inspect')
abort 'Unknown release action' unless %w[inspect prepare submit].include?(ACTION)
WHATS_NEW = 'Improved layouts across iPhone and iPad. Your selected screen and unfinished trip entries stay intact when resizing or switching between compact and wide layouts. Navigation remains accessible in shorter windows. Includes layout and stability improvements.'.freeze

def b64(value)
  Base64.urlsafe_encode64(value, padding: false)
end

key = OpenSSL::PKey.read(Base64.strict_decode64(ENV.fetch('API_KEY_BASE64').strip))
now = Time.now.to_i
header = { alg: 'ES256', kid: ENV.fetch('API_KEY_ID'), typ: 'JWT' }
claims = { iss: ENV.fetch('API_ISSUER_ID'), iat: now, exp: now + 1200,
           aud: 'appstoreconnect-v1' }
unsigned = "#{b64(header.to_json)}.#{b64(claims.to_json)}"
der = key.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest(unsigned))
signature = OpenSSL::ASN1.decode(der).value.map { |v| v.value.to_s(2).rjust(32, "\0") }.join
token = "#{unsigned}.#{b64(signature)}"
puts "::add-mask::#{token}"

def request(path, token, method = 'GET', body = nil)
  uri = URI("#{API_ROOT}#{path}")
  request = Net::HTTP.const_get(method.capitalize).new(uri)
  request['Authorization'] = "Bearer #{token}"
  if body
    request['Content-Type'] = 'application/json'
    request.body = JSON.generate(body)
  end
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
                            open_timeout: 20, read_timeout: 60) { |http| http.request(request) }
  unless response.is_a?(Net::HTTPSuccess)
    errors = JSON.parse(response.body).fetch('errors', []).map { |e| e.slice('status', 'code', 'title', 'detail', 'source') }
    abort "App Store API #{method} #{path.split('?').first} failed: #{errors.to_json}"
  end
  response.body.to_s.empty? ? {} : JSON.parse(response.body)
end

def get(path, token)
  request(path, token)
end

def relationship(type, id)
  { data: { type: type, id: id } }
end

versions = get("/v1/apps/#{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=200", token)
puts JSON.pretty_generate(versions.fetch('data').map { |v|
  { id: v['id'], version: v.dig('attributes', 'versionString'),
    state: v.dig('attributes', 'appStoreState'), release: v.dig('attributes', 'releaseType') }
})
builds = get("/v1/builds?filter[app]=#{APP_ID}&sort=-uploadedDate&limit=20&include=preReleaseVersion", token)
puts JSON.pretty_generate(builds.fetch('data').first(5).map { |b|
  { id: b['id'], build: b.dig('attributes', 'version'),
    processing: b.dig('attributes', 'processingState'),
    expired: b.dig('attributes', 'expired'),
    prerelease: b.dig('relationships', 'preReleaseVersion', 'data', 'id') }
})

target = versions.fetch('data').find { |v| v.dig('attributes', 'versionString') == VERSION }
if ACTION == 'prepare' && target.nil?
  target = request('/v1/appStoreVersions', token, 'POST', {
    data: { type: 'appStoreVersions',
            attributes: { platform: 'IOS', versionString: VERSION, releaseType: 'AFTER_APPROVAL' },
            relationships: { app: relationship('apps', APP_ID) } }
  }).fetch('data')
  puts "Created App Store version #{VERSION}: #{target.fetch('id')}"
end
exit if target.nil? && ACTION == 'inspect'
abort 'Prepare the target version first' unless target
version_id = target.fetch('id')
state = target.dig('attributes', 'appStoreState')
if %w[WAITING_FOR_REVIEW IN_REVIEW PENDING_APPLE_RELEASE PENDING_DEVELOPER_RELEASE READY_FOR_SALE].include?(state)
  puts "Version #{VERSION} already submitted or approved: #{state}"
  exit
end
abort "Version is not editable: #{state}" unless %w[PREPARE_FOR_SUBMISSION READY_FOR_REVIEW DEVELOPER_REJECTED REJECTED METADATA_REJECTED INVALID_BINARY].include?(state)

localizations = get("/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations", token).fetch('data')
abort 'Store localizations were not copied; metadata must be prepared' if localizations.empty?
localizations.each do |loc|
  if ACTION == 'prepare' && loc.dig('attributes', 'locale').start_with?('en-')
    request("/v1/appStoreVersionLocalizations/#{loc.fetch('id')}", token, 'PATCH', {
      data: { type: 'appStoreVersionLocalizations', id: loc.fetch('id'), attributes: { whatsNew: WHATS_NEW } }
    })
  end
  sets = get("/v1/appStoreVersionLocalizations/#{loc.fetch('id')}/appScreenshotSets?include=appScreenshots", token)
  puts JSON.generate(locale: loc.dig('attributes', 'locale'), screenshot_sets: sets.fetch('data').map { |s|
    { display: s.dig('attributes', 'screenshotDisplayType'), count: s.dig('relationships', 'appScreenshots', 'data')&.length }
  }, description_present: !loc.dig('attributes', 'description').to_s.empty?)
end
review_detail = get("/v1/appStoreVersions/#{version_id}/appStoreReviewDetail", token).fetch('data')
review_attributes = review_detail&.fetch('attributes', {}) || {}
puts JSON.generate(review_contact_complete: %w[contactFirstName contactLastName contactPhone contactEmail].all? { |k| !review_attributes[k].to_s.empty? },
                   review_notes_present: !review_attributes['notes'].to_s.empty?,
                   demo_account_required: review_attributes['demoAccountRequired'])

prerelease_ids = builds.fetch('included', []).select { |v|
  v['type'] == 'preReleaseVersions' && v.dig('attributes', 'version') == VERSION && v.dig('attributes', 'platform') == 'IOS'
}.map { |v| v.fetch('id') }
build = builds.fetch('data').find { |b|
  b.dig('attributes', 'version') == BUILD && prerelease_ids.include?(b.dig('relationships', 'preReleaseVersion', 'data', 'id'))
}
if build.nil? || build.dig('attributes', 'processingState') != 'VALID' || build.dig('attributes', 'expired')
  abort "Build #{VERSION} (#{BUILD}) is not yet valid for submission" if ACTION == 'submit'
  puts "Version metadata prepared; waiting for valid build #{VERSION} (#{BUILD})"
  exit
end
if ACTION == 'prepare'
  request("/v1/appStoreVersions/#{version_id}/relationships/build", token, 'PATCH', relationship('builds', build.fetch('id')))
  puts "Prepared #{VERSION} with build #{BUILD} (#{build.fetch('id')})"
end
exit unless ACTION == 'submit'
linked = get("/v1/appStoreVersions/#{version_id}/build", token).fetch('data')
abort 'Prepared build does not match the validated target build' unless linked&.fetch('id') == build.fetch('id')
submissions = get("/v1/apps/#{APP_ID}/reviewSubmissions?limit=200", token).fetch('data')
active = submissions.reject { |s| %w[COMPLETE CANCELED].include?(s.dig('attributes', 'state')) }
submission = active.find { |s| s.dig('attributes', 'state') == 'READY_FOR_REVIEW' }
abort 'Another review submission is active; inspect it before proceeding' if active.any? && submission.nil?
unless submission
  submission = request('/v1/reviewSubmissions', token, 'POST', {
    data: { type: 'reviewSubmissions', relationships: { app: relationship('apps', APP_ID) } }
  }).fetch('data')
end
submission_id = submission.fetch('id')
items = get("/v1/reviewSubmissions/#{submission_id}/items", token).fetch('data')
abort 'Review draft contains unrelated items' if items.any? { |i| i.dig('relationships', 'appStoreVersion', 'data', 'id') != version_id }
if items.empty?
  request('/v1/reviewSubmissionItems', token, 'POST', {
    data: { type: 'reviewSubmissionItems', relationships: {
      reviewSubmission: relationship('reviewSubmissions', submission_id),
      appStoreVersion: relationship('appStoreVersions', version_id)
    } }
  })
end
submitted = request("/v1/reviewSubmissions/#{submission_id}", token, 'PATCH', {
  data: { type: 'reviewSubmissions', id: submission_id, attributes: { submitted: true } }
}).fetch('data')
puts JSON.pretty_generate(submission: submission_id, state: submitted.dig('attributes', 'state'),
                          version: VERSION, build: BUILD)
