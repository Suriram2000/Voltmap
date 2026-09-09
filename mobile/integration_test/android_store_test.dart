import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voltmap/core/config/app_environment.dart';
import 'package:voltmap/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android production search, details, and map screenshots',
      (tester) async {
    expect(AppRuntimeConfig.isSandbox, isFalse);
    expect(AppRuntimeConfig.isAppleAppStoreBuild, isFalse);
    app.main();
    final search = find.byKey(const Key('locationField_Search across India'));
    await waitFor(tester, search);
    await tester.ensureVisible(search);
    await tester.enterText(search, '500079');
    await tester.pump(const Duration(milliseconds: 700));
    final submit = find.byKey(const Key('submitChargerSearchButton'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    final detailLinks = find.text('View charger details');
    await waitFor(tester, detailLinks);
    final detailLink = detailLinks.first;
    await tester.ensureVisible(detailLink);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('01-discover-android');

    await tester.tap(detailLink);
    await waitFor(
        tester, find.byKey(const Key('officialChargerDetailsScreen')));
    await waitFor(tester, find.byKey(const Key('chargerDetailsPhoto')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Representative station image'), findsOneWidget);
    await binding.takeScreenshot('02-station-details-android');
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));
    final mapTab = find.widgetWithText(NavigationDestination, 'Map');
    await tester.tap(mapTab);
    final mapField = find.descendant(
      of: find.byKey(const Key('mapLocationSearch')),
      matching: find.byType(TextField),
    );
    await waitFor(tester, mapField);
    await tester.enterText(mapField, '500079');
    FocusManager.instance.primaryFocus?.unfocus();
    await waitFor(tester, find.byKey(const Key('nearbyChargerMap')));
    await waitFor(tester, find.byKey(const Key('nearbyChargerPanel')));
    await tester.pump(const Duration(seconds: 2));
    await binding.takeScreenshot('03-map-android');
    expect(tester.takeException(), isNull);
  });
}

Future<void> waitFor(WidgetTester tester, Finder target) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (target.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(target, findsWidgets);
}
