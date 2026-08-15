import '../models/charging_receipt.dart';
import 'receipt_download_service_stub.dart'
    if (dart.library.io) 'receipt_download_service_io.dart'
    if (dart.library.js_interop) 'receipt_download_service_web.dart'
    as implementation;

class ReceiptDownloadService {
  const ReceiptDownloadService();

  Future<String> download(ChargingReceipt receipt) =>
      implementation.downloadReceipt(receipt);
}
