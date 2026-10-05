import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltmap/features/payments/presentation/charging_wallet_screen.dart';
import 'package:voltmap/shared/models/charging_wallet.dart';

void main() {
  test('parses a server-authoritative wallet snapshot', () {
    final wallet = ChargingWalletSnapshot.fromJson({
      'currency': 'INR',
      'availableBalanceInr': 340,
      'reservedBalanceInr': 60,
      'updatedAt': '2026-10-04T12:00:00Z',
      'transactions': [
        {
          'id': 'topup-1',
          'type': 'topUp',
          'amountInr': 400,
          'createdAt': '2026-10-04T12:00:00Z',
          'status': 'succeeded',
        },
      ],
    });

    expect(wallet.totalBalanceInr, 400);
    expect(wallet.transactions.single.isCredit, isTrue);
  });

  testWidgets('never presents a fabricated balance without a wallet backend',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ChargingWalletScreen())),
    );

    expect(find.text('Not connected'), findsOneWidget);
    expect(find.textContaining('No money can be added'), findsOneWidget);
  });
}
