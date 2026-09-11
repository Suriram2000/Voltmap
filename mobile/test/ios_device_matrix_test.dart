import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voltmap/app/voltmap_app.dart';
import 'package:voltmap/features/trips/presentation/trip_planner_screen.dart';

void main() {
  const devices = <_IPhoneLayout>[
    _IPhoneLayout('iPhone SE (1st generation)', Size(320, 568), 2),
    _IPhoneLayout('iPhone SE (2nd/3rd generation)', Size(375, 667), 2),
    _IPhoneLayout('iPhone 13 mini', Size(375, 812), 3),
    _IPhoneLayout('iPhone 15/16', Size(393, 852), 3),
    _IPhoneLayout('iPhone 14/15 Pro Max', Size(430, 932), 3),
    _IPhoneLayout('iPhone 16 Pro Max', Size(440, 956), 3),
    _IPhoneLayout('iPhone SE landscape', Size(568, 320), 2),
    _IPhoneLayout('iPhone 15/16 landscape', Size(852, 393), 3),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'voltmap_signed_in': true,
      'voltmap_profile_name': 'iPhone Test Driver',
      'voltmap_profile_email': 'iphone-test@voltmapev.com',
      'voltmap_account_salt': 'iphone-test-salt',
      'voltmap_account_password_hash': 'iphone-test-hash',
      'voltmapev_install_banner_dismissed': true,
    });
  });

  for (final device in devices) {
    testWidgets('${device.name} opens every primary tab without layout errors',
        (tester) async {
      _useIPhoneViewport(tester, device);

      await tester.pumpWidget(
        const ProviderScope(
          child: VoltMapApp(autoLocateDiscoverOnOpen: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Find the right charger, faster.'), findsOneWidget);
      _expectNoLayoutError(tester, '${device.name} Discover');

      await _openTab(
        tester,
        icon: Icons.map_outlined,
        expectedText: 'Find chargers near you',
      );
      _expectNoLayoutError(tester, '${device.name} Map');

      await _openTab(
        tester,
        icon: Icons.route_outlined,
        expectedText: 'Trip Planner',
      );
      _expectNoLayoutError(tester, '${device.name} Trips');

      await _openTab(
        tester,
        icon: Icons.favorite_border,
        expectedText: 'Favorites',
      );
      _expectNoLayoutError(tester, '${device.name} Favorites');

      await _openTab(
        tester,
        icon: Icons.add_location_alt_outlined,
        expectedText: 'Add a charging station',
      );
      _expectNoLayoutError(tester, '${device.name} Addstation');

      await _openTab(
        tester,
        icon: Icons.person_outline,
        expectedText: 'Profile & settings',
      );
      _expectNoLayoutError(tester, '${device.name} Profile');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('small iPhone remains usable with large accessibility text',
      (tester) async {
    _useIPhoneViewport(tester, devices.first);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.platformDispatcher.clearTextScaleFactorTestValue,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: VoltMapApp(autoLocateDiscoverOnOpen: false),
      ),
    );
    await tester.pumpAndSettle();

    _expectNoLayoutError(tester, 'small iPhone Discover at 200% text');
    await _openTab(
      tester,
      icon: Icons.map_outlined,
      expectedText: 'Find chargers near you',
    );
    _expectNoLayoutError(tester, 'small iPhone Map at 200% text');
    await _openTab(
      tester,
      icon: Icons.route_outlined,
      expectedText: 'Trip Planner',
    );
    _expectNoLayoutError(tester, 'small iPhone Trips at 200% text');
    await _openTab(
      tester,
      icon: Icons.favorite_border,
      expectedText: 'Favorites',
    );
    _expectNoLayoutError(tester, 'small iPhone Favorites at 200% text');
    await _openTab(
      tester,
      icon: Icons.add_location_alt_outlined,
      expectedText: 'Add a charging station',
    );
    _expectNoLayoutError(tester, 'small iPhone Addstation at 200% text');
    await _openTab(
      tester,
      icon: Icons.person_outline,
      expectedText: 'Profile & settings',
    );
    _expectNoLayoutError(tester, 'small iPhone Profile at 200% text');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  // Representative resizable windows, not claimed iPhone Duo device metrics.
  testWidgets('iOS resize keeps the selected tab and unfinished trip input',
      (tester) async {
    _useIPhoneViewport(tester, devices[3]);
    await tester.pumpWidget(const ProviderScope(
      child: VoltMapApp(autoLocateDiscoverOnOpen: false),
    ));
    await tester.pumpAndSettle();
    await _openTab(tester,
        icon: Icons.route_outlined, expectedText: 'Trip Planner');
    final tripState = tester.state(find.byType(TripPlannerScreen));
    final destination = find.descendant(
      of: find.byType(TripPlannerScreen),
      matching: find.byType(TextField),
    ).at(1);
    await tester.enterText(destination, 'Unfinished destination');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();

    for (final size in [
      const Size(760, 800),
      const Size(1024, 768),
      const Size(380, 800),
      const Size(393, 852),
    ]) {
      tester.view.physicalSize = size * 3;
      await tester.pumpAndSettle();
      _expectNoLayoutError(tester, 'iOS resize to $size');
      expect(find.text('Trip Planner'), findsOneWidget);
      expect(tester.state(find.byType(TripPlannerScreen)), same(tripState));
      expect(find.text('Unfinished destination'), findsOneWidget);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('wide short iOS window keeps every navigation item reachable',
      (tester) async {
    _useIPhoneViewport(tester,
        const _IPhoneLayout('resizable iOS window', Size(1024, 393), 3));
    await tester.pumpWidget(const ProviderScope(
      child: VoltMapApp(autoLocateDiscoverOnOpen: false),
    ));
    await tester.pumpAndSettle();
    _expectNoLayoutError(tester, 'wide short iOS window');
    final profile = find.byIcon(Icons.person_outline);
    await tester.ensureVisible(profile);
    await tester.tap(profile);
    await tester.pumpAndSettle();
    expect(find.text('Profile & settings'), findsOneWidget);
    _expectNoLayoutError(tester, 'wide short iOS Profile');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

Future<void> _openTab(
  WidgetTester tester, {
  required IconData icon,
  required String expectedText,
}) async {
  final navigation = find.byType(NavigationBar);
  await tester
      .tap(find.descendant(of: navigation, matching: find.byIcon(icon)));
  await tester.pumpAndSettle();
  expect(find.text(expectedText), findsWidgets);
}

void _useIPhoneViewport(WidgetTester tester, _IPhoneLayout device) {
  tester.view.devicePixelRatio = device.devicePixelRatio;
  tester.view.physicalSize = Size(
    device.logicalSize.width * device.devicePixelRatio,
    device.logicalSize.height * device.devicePixelRatio,
  );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _expectNoLayoutError(WidgetTester tester, String step) {
  final exception = tester.takeException();
  if (exception is FlutterError) {
    printOnFailure(exception.toStringDeep());
  }
  expect(
    exception,
    isNull,
    reason: '$step produced a Flutter layout/runtime exception.',
  );
}

class _IPhoneLayout {
  const _IPhoneLayout(
    this.name,
    this.logicalSize,
    this.devicePixelRatio,
  );

  final String name;
  final Size logicalSize;
  final double devicePixelRatio;
}
