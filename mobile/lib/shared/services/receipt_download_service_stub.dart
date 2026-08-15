import 'package:flutter/services.dart';

import '../models/charging_receipt.dart';

Future<String> downloadReceipt(ChargingReceipt receipt) async {
  await Clipboard.setData(ClipboardData(text: receipt.toPlainText()));
  return 'Receipt copied. Paste it into a document to save it.';
}
