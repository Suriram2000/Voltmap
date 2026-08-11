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

  test('sitemap contains only canonical public pages', () {
    final sitemap = File('web/sitemap.xml').readAsStringSync();
    expect(sitemap, contains('<loc>https://voltmapev.com/</loc>'));
    expect(
      sitemap,
      contains(
        '<loc>https://voltmapev.com/ev-charging-stations-india.html</loc>',
      ),
    );
    expect(RegExp(r'<loc>').allMatches(sitemap), hasLength(2));
  });

  test('manifest remains valid JSON with India charger positioning', () {
    final manifest = jsonDecode(File('web/manifest.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(manifest['name'], 'VoltMapEV');
    expect(manifest['description'], contains('India'));
    expect(manifest['categories'], contains('navigation'));
  });

  test('public guide carries source, safety, and contact disclosures', () {
    final guide = File(
      'web/ev-charging-stations-india.html',
    ).readAsStringSync();
    expect(guide, contains('29,277'));
    expect(guide, contains('1 August 2025'));
    expect(guide, contains('demonstration data'));
    expect(guide, contains('sandbox'));
    expect(guide, contains('skotla100@gmail.com'));
    expect(guide, contains('+91 93927 88714'));
  });
}
