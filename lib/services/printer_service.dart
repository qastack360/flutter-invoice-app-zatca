import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_printer_service.dart';


class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  BluetoothDevice? _selectedPrinter;

  BluetoothDevice? get selectedPrinter => _selectedPrinter;

  Future<void> loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMac = prefs.getString('saved_printer_mac');
    if (savedMac != null) {
      _selectedPrinter = BluetoothDevice(remoteId: DeviceIdentifier(savedMac));
    }
  }

  Future<void> setPrinterDevice(BluetoothDevice printer) async {
    _selectedPrinter = printer;
    await _savePrinter(printer);

    // Notify printer service about the new device
    await BluetoothPrinterService().setPrinterDevice(printer);
  }

  Future<void> _savePrinter(BluetoothDevice? printer) async {
    final prefs = await SharedPreferences.getInstance();
    if (printer == null) {
      await prefs.remove('saved_printer_mac');
    } else {
      await prefs.setString('saved_printer_mac', printer.remoteId.toString());
    }
  }

  Stream<BluetoothConnectionState> get connectionStatus {
    if (_selectedPrinter == null) {
      return Stream.value(BluetoothConnectionState.disconnected);
    }
    return _selectedPrinter!.connectionState;
  }
}