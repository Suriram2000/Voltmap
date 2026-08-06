import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voltmap/app/voltmap_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('search, favorites, navigation, and trip planning work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: VoltMapApp()));
    await tester.pumpAndSettle();

    expect(find.text('Find the right charger, faster.'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'Zeon');
    await tester.pumpAndSettle();
    expect(find.text('Zeon Charging Hub'), findsOneWidget);

    await tester.tap(find.byTooltip('Add to favorites').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(find.text('Zeon Charging Hub'), findsOneWidget);

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.text('Charger Map'), findsOneWidget);

    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Destination'),
      'Vijayawada',
    );
    await tester.tap(find.text('Plan route'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Estimated energy:'), findsOneWidget);
    expect(find.text('Save this trip'), findsOneWidget);
  });
}
