import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('iOS location privacy configuration', () {
    late String plist;

    setUpAll(() {
      plist = File('ios/Runner/Info.plist').readAsStringSync();
    });

    test('contains both location purpose strings required by Apple', () {
      expect(plist, contains('<key>NSLocationWhenInUseUsageDescription</key>'));
      expect(
        plist,
        contains('<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>'),
      );
    });

    test('explains the user benefit and background behavior clearly', () {
      final alwaysPurpose = RegExp(
        r'<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>\s*'
        r'<string>([^<]+)</string>',
      ).firstMatch(plist)?.group(1);

      expect(alwaysPurpose, isNotNull);
      expect(alwaysPurpose, contains('show nearby EV charging stations'));
      expect(alwaysPurpose, contains('calculate their distance'));
      expect(alwaysPurpose, contains('does not track'));
      expect(alwaysPurpose!.length, greaterThan(80));
    });

    test('does not declare background location execution', () {
      expect(plist, isNot(contains('<string>location</string>')));
      expect(plist, isNot(contains('<key>UIBackgroundModes</key>')));
    });
  });
}
