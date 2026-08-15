import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('homepage exposes canonical search and sharing metadata', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('<html lang="en-IN">'));
    expect(
      html,
      contains('<link rel="canonical" href="https://voltmapev.com/">'),
    );
    expect(html, contains('EV Charging Stations in India & Trip Planner'));
    expect(html, contains('application/ld+json'));
    expect(html, contains('"@type": "WebApplication"'));
    expect(html, contains('index,follow'));
    expect(html, contains('href="charging-stations/"'));
    expect(html, contains('rel="apple-touch-icon"'));

    final structuredData = RegExp(
      r'<script type="application/ld\+json">\s*(\{.*?\})\s*</script>',
      dotAll: true,
    ).firstMatch(html);
    expect(structuredData, isNotNull);
    final graph = jsonDecode(structuredData!.group(1)!) as Map<String, dynamic>;
    expect(graph['@context'], 'https://schema.org');
    expect(graph['@graph'], isA<List<dynamic>>());
  });

  test('robots allows search and AI discovery crawlers', () {
    final robots = File('web/robots.txt').readAsStringSync();
    for (final crawler in [
      'Googlebot',
      'Bingbot',
      'OAI-SearchBot',
      'ChatGPT-User',
      'OAI-AdsBot',
    ]) {
      expect(robots, contains('User-agent: $crawler'));
    }
    expect(robots, contains('Sitemap: https://voltmapev.com/sitemap.xml'));
    expect(robots.toLowerCase(), isNot(contains('disallow: /')));
  });

  test('sitemap contains every canonical public search page', () {
    final sitemap = File('web/sitemap.xml').readAsStringSync();
    expect(sitemap, contains('<loc>https://voltmapev.com/</loc>'));
    expect(
      sitemap,
      contains(
        '<loc>https://voltmapev.com/ev-charging-stations-india.html</loc>',
      ),
    );
    expect(
      sitemap,
      contains('<loc>https://voltmapev.com/charging-stations/</loc>'),
    );
    for (final city in [
      'hyderabad',
      'bengaluru',
      'delhi',
      'mumbai',
      'chennai',
      'pune',
      'ahmedabad',
      'kolkata',
      'jaipur',
      'kochi',
    ]) {
      expect(
        sitemap,
        contains(
          '<loc>https://voltmapev.com/charging-stations/$city.html</loc>',
        ),
      );
    }
    for (final legalPage in [
      'privacy-policy.html',
      'terms.html',
      'refund-policy.html',
      'account-deletion.html',
    ]) {
      expect(
        sitemap,
        contains('<loc>https://voltmapev.com/$legalPage</loc>'),
      );
      expect(File('web/$legalPage').readAsStringSync(), contains('VoltMapEV'));
    }
    expect(RegExp(r'<loc>').allMatches(sitemap), hasLength(17));
    expect(
      RegExp(r'<lastmod>2026-08-12</lastmod>').allMatches(sitemap),
      hasLength(13),
    );
    expect(
      RegExp(r'<lastmod>2026-08-13</lastmod>').allMatches(sitemap),
      hasLength(4),
    );
  });

  test('city guides are substantive, sourced, and uniquely canonical', () {
    final pages = Directory('web/charging-stations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.html'))
        .toList();
    expect(pages, hasLength(11));

    final canonicals = <String>{};
    for (final page in pages) {
      final html = page.readAsStringSync();
      expect(html, contains('<html lang="en-IN">'), reason: page.path);
      expect(html, contains('<h1>'), reason: page.path);
      expect(html, contains('<meta name="description"'), reason: page.path);
      expect(html, contains('application/ld+json'), reason: page.path);
      expect(html, contains('BEE'), reason: page.path);
      expect(
        html,
        anyOf(
          contains('not a live availability total'),
          contains('not real-time operational status'),
        ),
        reason: page.path,
      );
      expect(html, contains('href="/"'), reason: page.path);

      final structuredData = RegExp(
        r'<script type="application/ld\+json">\s*(\{.*?\})\s*</script>',
        dotAll: true,
      ).firstMatch(html);
      expect(structuredData, isNotNull, reason: page.path);
      final graph =
          jsonDecode(structuredData!.group(1)!) as Map<String, dynamic>;
      expect(graph['@context'], 'https://schema.org', reason: page.path);
      expect(graph['@graph'], isA<List<dynamic>>(), reason: page.path);

      final canonical = RegExp(
        '<link rel="canonical" href="([^"]+)">',
      ).firstMatch(html);
      expect(canonical, isNotNull, reason: page.path);
      expect(canonicals.add(canonical!.group(1)!), isTrue, reason: page.path);
    }
  });

  test('manifest remains valid JSON with India charger positioning', () {
    final manifest = jsonDecode(File('web/manifest.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(manifest['name'], 'VoltMapEV');
    expect(manifest['description'], contains('India'));
    expect(manifest['categories'], contains('navigation'));
    expect(manifest['display'], 'standalone');
    expect(manifest['background_color'], '#071D17');
    expect(manifest['start_url'], '/?source=pwa');
    final icons = manifest['icons'] as List<dynamic>;
    expect(
      icons.where(
        (value) => (value as Map<String, dynamic>)['sizes'] == '192x192',
      ),
      isNotEmpty,
    );
    expect(
      icons.where(
        (value) => (value as Map<String, dynamic>)['sizes'] == '512x512',
      ),
      hasLength(2),
    );
    expect(
      icons.where(
        (value) => (value as Map<String, dynamic>)['purpose'] == 'maskable',
      ),
      hasLength(1),
    );
    for (final icon in icons.cast<Map<String, dynamic>>()) {
      final file = File('web/${icon['src']}');
      expect(file.existsSync(), isTrue, reason: file.path);
      expect(file.lengthSync(), greaterThan(4000), reason: file.path);
    }
    expect(
      File('web/icons/apple-touch-icon.png').lengthSync(),
      greaterThan(4000),
    );
  });

  test('web bootstrap captures safe install and installed events', () {
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(bootstrap, contains("'beforeinstallprompt'"));
    expect(bootstrap, contains("'appinstalled'"));
    expect(bootstrap, contains('window.voltMapEVInstallStatus'));
    expect(bootstrap, contains('window.voltMapEVPromptInstall'));
    expect(bootstrap, contains("choice.outcome === 'accepted'"));
    expect(bootstrap, contains('voltmapev-pwa-cache-reset-v2'));
  });

  test('web startup immediately paints a branded shell', () {
    final index = File('web/index.html').readAsStringSync();
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();

    expect(index, contains('id="boot-splash"'));
    expect(index, contains('Opening VoltMapEV'));
    expect(
      index,
      contains('VoltMapEV – The Best EV Charging Station Finder'),
    );
    expect(index, contains('background: #071D17'));
    expect(bootstrap, contains('onEntrypointLoaded'));
    expect(bootstrap, contains("document.getElementById('boot-splash')"));
    expect(bootstrap, contains('splash.remove()'));
    expect(
      bootstrap.indexOf('removeLegacyFlutterWebCache().catch'),
      lessThan(bootstrap.indexOf('_flutter.loader.load')),
    );
  });

  test('public guide carries source, safety, and contact disclosures', () {
    final guide = File(
      'web/ev-charging-stations-india.html',
    ).readAsStringSync();
    expect(guide, contains('29,277'));
    expect(guide, contains('1 August 2025'));
    expect(guide, contains('29,251 deduplicated, geocoded BEE'));
    expect(guide, contains('26 October 2025'));
    expect(guide, contains('sandbox'));
    expect(guide, contains('skotla100@gmail.com'));
    expect(guide, contains('+91 93927 88714'));
  });

  test('llms guidance describes the dated official index without live claims',
      () {
    final guidance = File('web/llms.txt').readAsStringSync();
    expect(guidance, contains('https://voltmapev.com/charging-stations/'));
    expect(guidance, contains('29,251 deduplicated, geocoded BEE'));
    expect(guidance, contains('not a complete real-time feed'));
  });
}
