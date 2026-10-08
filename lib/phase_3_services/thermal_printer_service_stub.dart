import 'package:hive/hive.dart';
import 'package:salesvista/phase_2_models/invoice_model.dart';

class ThermalPrinterConfig {
  final String ipAddress;
  final int port;
  final int widthChars;
  final Duration timeout;

  const ThermalPrinterConfig({
    required this.ipAddress,
    this.port = 9100,
    this.widthChars = 48,
    this.timeout = const Duration(seconds: 4),
  });

  bool get isConfigured => ipAddress.trim().isNotEmpty;

  static Future<ThermalPrinterConfig> load() async {
    final box = Hive.isBoxOpen('settingsBox')
        ? Hive.box('settingsBox')
        : await Hive.openBox('settingsBox');

    return ThermalPrinterConfig(
      ipAddress: box.get('thermalPrinterIp', defaultValue: '').toString().trim(),
      port: int.tryParse(box.get('thermalPrinterPort', defaultValue: '9100').toString()) ?? 9100,
      widthChars: int.tryParse(box.get('thermalPrinterWidthChars', defaultValue: '48').toString()) ?? 48,
    );
  }

  Future<void> save() async {
    final box = Hive.isBoxOpen('settingsBox')
        ? Hive.box('settingsBox')
        : await Hive.openBox('settingsBox');
    await box.put('thermalPrinterIp', ipAddress.trim());
    await box.put('thermalPrinterPort', port.toString());
    await box.put('thermalPrinterWidthChars', widthChars.toString());
  }
}

class ThermalPrintResult {
  final bool success;
  final String message;

  const ThermalPrintResult({required this.success, required this.message});
}

class ThermalPrinterService {
  static bool get isDirectPrintSupported => false;

  static Future<ThermalPrintResult> testConnection(ThermalPrinterConfig config) async {
    return const ThermalPrintResult(
      success: false,
      message: 'Direct ESC/POS printing is not available on web/Chrome. Use Android/Windows app or PDF print fallback.',
    );
  }

  static Future<ThermalPrintResult> printWalkInInvoice(
    InvoiceModel invoice, {
    required ThermalPrinterConfig config,
  }) async {
    return const ThermalPrintResult(
      success: false,
      message: 'Direct ESC/POS printing is not available on web/Chrome. Use Android/Windows app or PDF print fallback.',
    );
  }
}
