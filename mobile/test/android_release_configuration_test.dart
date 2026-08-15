import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android release configuration', () {
    late String manifest;
    late String gradle;

    setUpAll(() {
      manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      gradle = File('android/app/build.gradle.kts').readAsStringSync();
    });

    test('requests only internet and foreground location permissions', () {
      final permissions = RegExp(
        r'<uses-permission android:name="([^"]+)"\s*/>',
      ).allMatches(manifest).map((match) => match.group(1)).toSet();

      expect(
        permissions,
        {
          'android.permission.INTERNET',
          'android.permission.ACCESS_COARSE_LOCATION',
          'android.permission.ACCESS_FINE_LOCATION',
        },
      );
      expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
      expect(manifest, isNot(contains('READ_SMS')));
      expect(manifest, isNot(contains('READ_CONTACTS')));
      expect(manifest, isNot(contains('READ_MEDIA')));
    });

    test('protects local data and blocks cleartext traffic', () {
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:usesCleartextTraffic="false"'));
      expect(manifest, contains('android:networkSecurityConfig='));
      expect(manifest, contains('android:dataExtractionRules='));
      expect(manifest, contains('android:fullBackupContent='));

      final networkRules = File(
        'android/app/src/main/res/xml/network_security_config.xml',
      ).readAsStringSync();
      expect(networkRules, contains('cleartextTrafficPermitted="false"'));

      for (final file in ['backup_rules.xml', 'data_extraction_rules.xml']) {
        final contents = File(
          'android/app/src/main/res/xml/$file',
        ).readAsStringSync();
        expect(contents, contains('domain="sharedpref"'), reason: file);
        expect(contents, contains('domain="database"'), reason: file);
      }
    });

    test('provides adaptive, round, themed and Android 12 splash assets', () {
      for (final path in [
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml',
        'android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml',
        'android/app/src/main/res/mipmap-anydpi-v33/ic_launcher_round.xml',
        'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
        'android/app/src/main/res/drawable/ic_launcher_monochrome.xml',
        'android/app/src/main/res/values-v31/styles.xml',
        'android/app/src/main/res/values-night-v31/styles.xml',
      ]) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
      expect(
          manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
      expect(manifest, contains('android:enableOnBackInvokedCallback="true"'));
      expect(
        File(
          'android/app/src/main/res/values-v31/styles.xml',
        ).readAsStringSync(),
        contains('android:windowSplashScreenAnimatedIcon'),
      );
      expect(
        File(
          'android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml',
        ).readAsStringSync(),
        contains('<monochrome'),
      );
    });

    test('uses the permanent package and never falls back to debug signing',
        () {
      expect(gradle, contains('applicationId = "in.voltmap.voltmap"'));
      expect(gradle, contains('targetSdk = flutter.targetSdkVersion'));
      expect(gradle, contains('sourceCompatibility = JavaVersion.VERSION_17'));
      expect(gradle, contains('keystorePropertiesFile.exists()'));
      expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('version: 1.12.1+16'),
      );
    });
  });
}
