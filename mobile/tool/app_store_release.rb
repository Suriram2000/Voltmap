# Read-only release inspection using the existing App Store upload credentials.
# Never print private keys, tokens, reviewer credentials, or contact details.
require 'base64'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

APP_ID = '6801616483'.freeze
API_ROOT = 'https://api.appstoreconnect.apple.com'.freeze

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

def get(path, token)
  uri = URI("#{API_ROOT}#{path}")
  request = Net::HTTP::Get.new(uri)
  request['Authorization'] = "Bearer #{token}"
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
                            open_timeout: 20, read_timeout: 60) { |http| http.request(request) }
  unless response.is_a?(Net::HTTPSuccess)
    abort "App Store API request failed: HTTP #{response.code} #{response.body}"
  end
  JSON.parse(response.body)
end

versions = get("/v1/apps/#{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=10", token)
puts JSON.pretty_generate(versions.fetch('data').map { |v|
  { id: v['id'], version: v.dig('attributes', 'versionString'),
    state: v.dig('attributes', 'appStoreState'), release: v.dig('attributes', 'releaseType') }
})
builds = get("/v1/builds?filter[app]=#{APP_ID}&sort=-uploadedDate&limit=5&include=preReleaseVersion", token)
puts JSON.pretty_generate(builds.fetch('data').map { |b|
  { id: b['id'], build: b.dig('attributes', 'version'),
    processing: b.dig('attributes', 'processingState'),
    expired: b.dig('attributes', 'expired'),
    prerelease: b.dig('relationships', 'preReleaseVersion', 'data', 'id') }
})
