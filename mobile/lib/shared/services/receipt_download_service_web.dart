import 'dart:js_interop';

import '../models/charging_receipt.dart';

@JS('voltMapEVDownloadTextFile')
external void _downloadTextFile(JSString filename, JSString content);

Future<String> downloadReceipt(ChargingReceipt receipt) async {
  final safeId = receipt.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  _downloadTextFile(
    'VoltMapEV-$safeId.txt'.toJS,
    receipt.toPlainText().toJS,
  );
  return 'Receipt download started.';
}
