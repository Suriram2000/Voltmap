import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltmap/features/payments/presentation/charging_payment_plan_screen.dart';
import 'package:voltmap/shared/models/charging_payment_plan.dart';

void main() {
  test('falls back safely when a stored payment plan is malformed', () {
    final plan = ChargingPaymentPlan.fromJson(const {
      'kind': 'unexpected',
      'maximumAmountInr': -12,
    });

    expect(plan.kind, ChargingPaymentPlanKind.payAsYouCharge);
    expect(plan.maximumAmountInr, 1000);
  });

  testWidgets('driver can choose a charging budget guard', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ChargingPaymentPlanScreen()),
      ),
    );

    await tester.tap(find.text('Charging budget guard'));
    await tester.pump();

    expect(find.byKey(const Key('paymentPlanBudgetSlider')), findsOneWidget);
  });
}
