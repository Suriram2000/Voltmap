import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../models/charging_receipt.dart';

Future<String> downloadReceipt(ChargingReceipt receipt) async {
  final safeId = receipt.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final file = File('${Directory.systemTemp.path}/VoltMapEV-$safeId.txt');
  await file.writeAsString(receipt.toPlainText(), flush: true);
  final opened =
      await launchUrl(file.uri, mode: LaunchMode.externalApplication);
  return opened
      ? 'Receipt exported to ${file.path}.'
      : 'Receipt saved to ${file.path}.';
}
