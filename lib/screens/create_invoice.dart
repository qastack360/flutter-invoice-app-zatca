import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../models/company_details.dart';
import '../models/item_data.dart';
import '../utils/invoice_helper.dart';
import '../widgets/add_item_popup.dart';
import '../widgets/invoice_totals.dart';
import '../widgets/item_row.dart'; // Fixed import
import '../services/bluetooth_printer_service.dart';
import '../services/printer_service.dart';
import '../services/qr_service.dart';
import 'package:my_invoice_app/screens/preview_invoice_screen.dart';
import 'package:printing/printing.dart'; // for convertPdfToImage
import 'package:pdf/pdf.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'package:pdfx/pdfx.dart' as pdfx;

class CreateInvoiceScreen extends StatefulWidget {
  final ValueNotifier<bool> refreshNotifier;

  const CreateInvoiceScreen({Key? key, required this.refreshNotifier}) : super(key: key);

  @override
  _CreateInvoiceScreenState createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();
  final _salesmanCtrl = TextEditingController(text: 'Employee');
  final _customerCtrl = TextEditingController(text: 'Walk-In Customer');
  final _customerVatCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  final _manualMacCtrl = TextEditingController();

  List<ItemData> _items = [];
  int _invoiceNo = 1;
  int _zatcaInvoiceNo = 1;
  int _localInvoiceNo = 1;
  double _vatPercent = 15;
  String? _logoPath;
  List<Map<String, dynamic>> _history = [];
  CompanyDetails? _companyDetails;
  final BluetoothPrinterService _printerService = BluetoothPrinterService();
  final PrinterService _printerSelectionService = PrinterService();
  bool _isScanning = false;
  List<BluetoothDevice> _discoveredDevices = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _showManualInput = false;
  bool _permissionsGranted = false;
  bool _isConnecting = false;
  bool _sendToZatca = false; // New toggle for ZATCA integration

  String get _date => DateFormat('yyyy-MM-dd – HH:mm').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadHistory();
    _loadCompanyDetails();
    widget.refreshNotifier.addListener(_refreshData);
    _printerSelectionService.loadSavedPrinter();
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_refreshData);
    _stopScan();
    super.dispose();
  }

  void _refreshData() {
    _loadSettings();
    _loadCompanyDetails();
  }

  Future<bool> _requestPermissions() async {
    if (!_permissionsGranted) {
      final permissions = await [
        Permission.bluetooth,
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      final allGranted = permissions.values.every((status) => status.isGranted);
      if (allGranted) {
        setState(() => _permissionsGranted = true);
      }
      return allGranted;
    }
    return true;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _invoiceNo = prefs.getInt('startInvoice') ?? 1;
      _zatcaInvoiceNo = prefs.getInt('zatcaStartInvoice') ?? 1;
      _localInvoiceNo = prefs.getInt('localStartInvoice') ?? 1;
      _vatPercent = prefs.getDouble('vatPercent') ?? 15;
    });
  }

  Future<void> _loadCompanyDetails() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('company_details', where: 'id=1');
    if (rows.isNotEmpty) {
      setState(() {
        _companyDetails = CompanyDetails.fromMap(rows.first);
      });
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('invoices') ?? [];
    setState(() {
      _history = data.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
    });
  }

  Future<void> _saveToHistory() async {
    // Determine invoice number based on ZATCA toggle
    final invoiceNumber = _sendToZatca ? _zatcaInvoiceNo : _localInvoiceNo;
    final invoicePrefix = _sendToZatca ? 'ZATCA' : 'LOCAL';
    
    final record = {
      'no': invoiceNumber,
      'invoice_prefix': invoicePrefix,
      'date': _date,
      'salesman': _salesmanCtrl.text,
      'customer': _customerCtrl.text,
      'customerVat': _customerVatCtrl.text,
      'items': _items.map((it) => it.toMap()).toList(),
      'vatPercent': _vatPercent,
      'discount': double.tryParse(_discountCtrl.text) ?? 0,
      'cash': double.tryParse(_cashCtrl.text) ?? 0,
      'zatca_invoice': _sendToZatca,
      'zatca_environment': _sendToZatca ? 'live' : null, // Will be updated from settings
      'sync_status': _sendToZatca ? 'pending' : 'local',
      'created_at': DateTime.now().toIso8601String(),
    };
    
    _history.add(record);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('invoices', _history.map((e) => jsonEncode(e)).toList());
    
    // Increment the appropriate invoice counter
    if (_sendToZatca) {
      _zatcaInvoiceNo++;
      await prefs.setInt('zatcaStartInvoice', _zatcaInvoiceNo);
    } else {
      _localInvoiceNo++;
      await prefs.setInt('localStartInvoice', _localInvoiceNo);
    }
  }

  void _showAddItemOptions() {
    showDialog<ItemData>(
      context: context,
      builder: (_) => const AddItemPopup(),
    ).then((newItem) {
      if (newItem != null) {
        final existingIndex = _items.indexWhere((item) =>
        item.description.trim().toLowerCase() == newItem.description.trim().toLowerCase());
        if (existingIndex >= 0) {
          setState(() {
            _items[existingIndex].quantity += newItem.quantity;
          });
        } else {
          setState(() => _items.add(newItem));
        }
      }
    });
  }

  Future<void> _incrementInvoice() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _invoiceNo++);
    await prefs.setInt('startInvoice', _invoiceNo);
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _items.clear();
      _salesmanCtrl.text = 'Employee';
      _customerCtrl.text = 'Walk-In Customer';
      _customerVatCtrl.clear();
      _discountCtrl.clear();
      _cashCtrl.clear();
      _loadSettings();
    });
  }

  Future<void> _startScan(void Function(BluetoothDevice) onDeviceFound) async {
    if (_isScanning) return;

    // Request permissions before scanning
    if (!await _requestPermissions()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth permissions required')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
    });

    try {
      // Check Bluetooth state
      if (!await FlutterBluePlus.isSupported) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth not supported on this device')),
        );
        setState(() => _isScanning = false);
        return;
      }

      final state = await FlutterBluePlus.adapterState.first;
      if (state == BluetoothAdapterState.off) {
        await FlutterBluePlus.turnOn();
      }

      // Start scan
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;

        for (ScanResult result in results) {
          if (!_discoveredDevices.any((d) => d.remoteId == result.device.remoteId)) {
            onDeviceFound(result.device);
          }
        }
      }, onError: (e) {
        print("Scan error: $e");
      });
    } catch (e) {
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan error: $e')),
      );
    }
  }

  void _stopScan() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    setState(() => _isScanning = false);
  }

  String _formatMac(String input) {
    // Remove any non-alphanumeric characters
    String cleaned = input.replaceAll(RegExp(r'[^a-fA-F0-9]'), '');

    // Format as AA:BB:CC:DD:EE:FF
    StringBuffer formatted = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 2 == 0) {
        formatted.write(':');
      }
      if (i < cleaned.length) {
        formatted.write(cleaned[i]);
      }
    }

    return formatted.toString().toUpperCase();
  }

  bool _isValidMac(String mac) {
    // Check if it matches AA:BB:CC:DD:EE:FF format
    final RegExp macRegex = RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$');
    return macRegex.hasMatch(mac);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() => _isConnecting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Connecting to Printer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Center(child: CircularProgressIndicator()),
            SizedBox(height: 20),
            Text('Please wait...'),
          ],
        ),
      ),
    );

    try {
      // First disconnect if already connected
      if (device.connectionState == BluetoothConnectionState.connected) {
        await device.disconnect();
        await Future.delayed(const Duration(seconds: 1));
      }

      // Connect to device
      await device.connect(
        autoConnect: false,  // Disable auto-connect
        timeout: const Duration(seconds: 15),
      );

      await device.connectionState
          .where((state) => state == BluetoothConnectionState.connected)
          .first
          .timeout(const Duration(seconds: 15));

      // Set up printer characteristics
      await _printerSelectionService.setPrinterDevice(device);

      // Close dialogs
      Navigator.of(context).pop(); // Close connecting dialog
      Navigator.of(context).pop(); // Close printer selection dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer connected successfully!')),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close connecting dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: ${e.toString()}')),
      );
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  Future<void> _connectManualPrinter() async {
    String mac = _manualMacCtrl.text.trim();

    // Format to standard MAC format
    String formattedMac = _formatMac(mac);

    if (!_isValidMac(formattedMac)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid MAC address format (use AA:BB:CC:DD:EE:FF)')),
      );
      return;
    }

    try {
      final device = BluetoothDevice(remoteId: DeviceIdentifier(formattedMac));
      await _connectToDevice(device);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    }
  }

  void _showPrinterDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            void onDeviceFound(BluetoothDevice device) {
              if (!_discoveredDevices.any((d) => d.remoteId == device.remoteId)) {
                setDialogState(() {
                  _discoveredDevices.add(device);
                });
              }
            }

            return AlertDialog(
              title: const Text('Select Printer'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    if (_showManualInput)
                      Column(
                        children: [
                          TextField(
                            controller: _manualMacCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Enter Printer MAC Address',
                              hintText: 'AA:BB:CC:DD:EE:FF',
                            ),
                            onChanged: (value) {
                              // Format as user types
                              final formatted = _formatMac(value);
                              if (formatted != value) {
                                _manualMacCtrl.value = TextEditingValue(
                                  text: formatted,
                                  selection: TextSelection.collapsed(offset: formatted.length),
                                );
                              }

                              setDialogState(() {});
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setDialogState(() {
                                    _showManualInput = false;
                                  });
                                },
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: _isConnecting ? null : _connectManualPrinter,
                                child: const Text('Connect'),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      Expanded(
                        child: _discoveredDevices.isEmpty
                            ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isScanning)
                              const Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 20),
                                  Text('Scanning for devices...')
                                ],
                              )
                            else
                              const Text('No devices found'),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () => _startScan(onDeviceFound),
                              child: const Text('Start Scan'),
                            )
                          ],
                        )
                            : ListView.builder(
                          itemCount: _discoveredDevices.length,
                          itemBuilder: (context, index) {
                            final device = _discoveredDevices[index];
                            return ListTile(
                              title: Text(device.name.isNotEmpty ? device.name : 'Unknown Device'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(device.remoteId.toString()),
                                  StreamBuilder<BluetoothConnectionState>(
                                    stream: device.connectionState,
                                    initialData: BluetoothConnectionState.disconnected,
                                    builder: (c, snapshot) {
                                      return Text(
                                        'Status: ${snapshot.data?.toString().split('.').last}',
                                        style: TextStyle(
                                          color: snapshot.data == BluetoothConnectionState.connected
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              trailing: _isConnecting
                                  ? const CircularProgressIndicator()
                                  : ElevatedButton(
                                onPressed: () async {
                                  await _connectToDevice(device);
                                },
                                child: const Text('Connect'),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _isConnecting ? null : () {
                        setDialogState(() {
                          _showManualInput = !_showManualInput;
                        });
                      },
                      child: Text(_showManualInput ? 'Back to Scanner' : 'Enter MAC Address Manually'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _stopScan();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          }
      ),
    );
  }

  Future<bool> _isMockPrinting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('mockPrinting') ?? false;
  }

  // FIXED: PDF to image conversion
  Future<Uint8List?> _generateInvoiceImage() async {
    try {
      // Generate QR data
      final subtotal = _items.fold<double>(0, (sum, it) => sum + it.quantity * it.rate);
      final discountValue = double.tryParse(_discountCtrl.text) ?? 0;
      final vatAmount = subtotal * _vatPercent / 100;
      final total = subtotal + vatAmount - discountValue;
      final cashValue = double.tryParse(_cashCtrl.text) ?? 0;

      final qrData = "INV:$_invoiceNo"
          "|SALESMAN:${_salesmanCtrl.text}"
          "|CUSTOMER:${_customerCtrl.text}"
          "|VATNO:${_customerVatCtrl.text}"
          "|DISCOUNT:${discountValue.toStringAsFixed(2)}"
          "|VATAMOUNT:${vatAmount.toStringAsFixed(2)}"
          "|TOTAL:${total.toStringAsFixed(2)}"
          "|CASH:${cashValue.toStringAsFixed(2)}"
          "|CHANGE:${(cashValue - total).toStringAsFixed(2)}"
          "|DATE:$_date";

      // Generate PDF
      final Uint8List pdfBytes = await InvoiceHelper.generatePdf(
        invoiceNo: _invoiceNo,
        date: _date,
        salesman: _salesmanCtrl.text,
        customer: _customerCtrl.text,
        vatNo: _customerVatCtrl.text,
        items: _items,
        vatPercent: _vatPercent,
        discount: discountValue,
        cash: cashValue,
        companyDetails: _companyDetails,
        qrData: qrData,
      );

      // Open and render using pdfx
      final doc = await pdfx.PdfDocument.openData(pdfBytes);
      final page = await doc.getPage(1);
      final pageImage = await page.render(
        width: (page.width * 3).toDouble(),
        height: (page.height * 3).toDouble(),
      );

      final imageData = pageImage?.bytes;
      await page.close();
      await doc.close();

      return imageData;
    } catch (e) {
      print("Error generating invoice image: $e");
      return null;
    }
  }

  // FIXED: Preview invoice
  Future<void> _previewInvoice() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    try {
      final imageData = await _generateInvoiceImage();
      if (imageData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate preview')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewInvoiceScreen(imageData: imageData),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview error: $e')),
      );
    }
  }

  // FIXED: Print thermal invoice
  Future<void> _printThermalInvoice() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    try {
      final mockPrinting = await _isMockPrinting();

      // Generate invoice image
      final imageData = await _generateInvoiceImage();
      if (imageData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate invoice image')),
        );
        return;
      }

      if (mockPrinting) {
        // Show image preview for mock printing
        await showDialog(
          context: context,
          builder: (context) => Dialog(
            insetPadding: const EdgeInsets.all(10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: SingleChildScrollView(
                child: Image.memory(imageData),
              ),
            ),
          ),
        );
      } else {
        if (_printerSelectionService.selectedPrinter == null) {
          _showPrinterDialog();
          return;
        }

        // Print the image
        await _printerService.printRasterImage(imageData);
      }

      // Save and reset
      await _saveToHistory();
      await _incrementInvoice();
      _resetForm();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice processed successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    final subtotal = _items.fold<double>(0, (sum, it) => sum + it.quantity * it.rate);
    final discount = double.tryParse(_discountCtrl.text) ?? 0;
    final vatAmount = _items.fold<double>(0, (sum, it) => sum + (it.quantity * it.rate * _vatPercent / 100));
    final total = subtotal + vatAmount - discount;
    final cash = double.tryParse(_cashCtrl.text) ?? 0;
    final change = cash - total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Invoice / إنشاء فاتورة'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              if (_companyDetails != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_companyDetails!.ownerName1.isNotEmpty)
                      Text(
                        _companyDetails!.ownerName1,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    if (_companyDetails!.ownerName2.isNotEmpty)
                      Text(
                        _companyDetails!.ownerName2,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    if (_companyDetails!.phone.isNotEmpty)
                      Text(
                        'Phone: ${_companyDetails!.phone}',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    if (_companyDetails!.vatNo.isNotEmpty)
                      Text(
                        'VAT: ${_companyDetails!.vatNo}',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildReadOnly('Invoice No / رقم الفاتورة', _invoiceNo.toString()),
                      const SizedBox(height: 12),
                      _buildReadOnly('Date / التاريخ', _date),
                      const SizedBox(height: 12),
                      _buildEditable(_salesmanCtrl, 'Sales Man / الموظف', isRequired: true),
                      const SizedBox(height: 12),
                      _buildEditable(_customerCtrl, 'Customer / العميل', isRequired: true),
                      const SizedBox(height: 12),
                      _buildEditable(_customerVatCtrl, 'Customer VAT No / الرقم الضريبي'),
                      const SizedBox(height: 12),
                      // ZATCA Integration Toggle
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          border: Border.all(color: Colors.orange[200]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.qr_code, color: Colors.orange[700]),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Send to ZATCA / إرسال إلى ضريبة القيمة المضافة',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                  Text(
                                    'Enable to send invoice to Saudi e-invoicing system',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _sendToZatca,
                              onChanged: (value) {
                                setState(() {
                                  _sendToZatca = value;
                                });
                              },
                              activeColor: Colors.orange,
                            ),
                          ],
                        ),
                      ),
                      if (_sendToZatca) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            border: Border.all(color: Colors.green[200]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.green[700], size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Invoice will be sent to ZATCA system. Number: ${_sendToZatca ? "ZATCA-$_zatcaInvoiceNo" : "LOCAL-$_localInvoiceNo"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: const Row(
                  children: [
                    Expanded(child: Text('No\nرقم', textAlign: TextAlign.center)),
                    Expanded(flex: 3, child: Text('Description\nالوصف', textAlign: TextAlign.center)),
                    Expanded(child: Text('Qty\nالكمية', textAlign: TextAlign.center)),
                    Expanded(child: Text('Rate\nالسعر', textAlign: TextAlign.center)),
                    Expanded(child: Text('VAT\nالضريبة', textAlign: TextAlign.center)),
                    Expanded(child: Text('Amount\nالمجموع', textAlign: TextAlign.center)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _items.length; i++)
                ItemRow( // FIXED: Correct widget name
                  key: ValueKey(_items[i]),
                  index: i,
                  item: _items[i],
                  vatPercent: _vatPercent,
                  onDelete: () => setState(() => _items.removeAt(i)),
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Item / إضافة عنصر'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _showAddItemOptions,
              ),
              const SizedBox(height: 24),
              InvoiceTotals(
                items: _items,
                vatPercent: _vatPercent,
                discountCtrl: _discountCtrl,
                cashCtrl: _cashCtrl,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _printThermalInvoice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    child: const Text('Print', style: TextStyle(fontSize: 18)),
                  ),
                  ElevatedButton(
                    onPressed: _previewInvoice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    child: const Text('Preview', style: TextStyle(fontSize: 18)),
                  ),
                  ElevatedButton(
                    onPressed: _resetForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    child: const Text('Reset', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Column(
                children: [
                  if (_printerSelectionService.selectedPrinter != null)
                    Text(
                      'Printer: ${_printerSelectionService.selectedPrinter!.name}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),

                  TextButton(
                    onPressed: _isScanning ? null : _showPrinterDialog,
                    child: Text(_isScanning
                        ? 'Scanning for printers... / البحث عن الطابعات...'
                        : 'Select Bluetooth Printer / اختيار طابعة بلوتوث'),
                  ),
                  StreamBuilder<BluetoothConnectionState>(
                    stream: _printerSelectionService.selectedPrinter?.connectionState,
                    initialData: BluetoothConnectionState.disconnected,
                    builder: (c, snapshot) {
                      final state = snapshot.data;
                      return Text(
                        'Status: ${state?.toString().split('.').last ?? 'N/A'}',
                        style: TextStyle(
                          color: state == BluetoothConnectionState.connected
                              ? Colors.green
                              : Colors.red,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnly(String label, String value) => TextFormField(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    readOnly: true,
  );

  Widget _buildEditable(TextEditingController ctrl, String label, {bool isRequired = false}) => TextFormField(
    controller: ctrl,
    decoration: InputDecoration(
      labelText: label,
      errorStyle: const TextStyle(color: Colors.red),
    ),
    validator: (v) {
      if (isRequired && (v == null || v.isEmpty)) {
        return 'Required field';
      }
      return null;
    },
  );
}