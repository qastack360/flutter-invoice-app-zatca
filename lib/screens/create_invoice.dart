import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import '../widgets/item_row.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/printer_service.dart';
import '../services/qr_service.dart';
import 'package:my_invoice_app/screens/preview_invoice_screen.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../services/supabase_service.dart'; // Added for ZATCA sync

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
  final SupabaseService _supabaseService = SupabaseService(); // Added for ZATCA sync
  bool _isScanning = false;
  List<BluetoothDevice> _discoveredDevices = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _showManualInput = false;
  bool _permissionsGranted = false;
  bool _isConnecting = false;
  bool _sendToZatca = false; // New toggle for ZATCA integration
  String _currentZatcaEnvironment = 'live'; // Current ZATCA environment

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
      _currentZatcaEnvironment = prefs.getString('zatcaEnvironment') ?? 'live';
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
    final invoicePrefix = _sendToZatca ? 'ZATCA' : 'INV_NO';
    
    // Calculate totals
    final subtotal = _items.fold<double>(0, (sum, it) => sum + it.quantity * it.rate);
    final discount = double.tryParse(_discountCtrl.text) ?? 0;
    final vatAmount = _items.fold<double>(0, (sum, it) => sum + (it.quantity * it.rate * _vatPercent / 100));
    final total = subtotal + vatAmount - discount;
    
    final record = {
      'no': invoiceNumber,
      'invoice_prefix': invoicePrefix,
      'date': _date,
      'salesman': _salesmanCtrl.text,
      'customer': _customerCtrl.text,
      'vatNo': _customerVatCtrl.text, // Changed from customerVat to vatNo
      'items': _items.map((it) => it.toMap()).toList(),
      'vatPercent': _vatPercent,
      'discount': discount,
      'cash': double.tryParse(_cashCtrl.text) ?? 0,
      'total': total, // Added total field
      'vatAmount': vatAmount, // Added vatAmount field
      'subtotal': subtotal, // Added subtotal field
      'zatca_invoice': _sendToZatca,
      'zatca_environment': _sendToZatca ? _currentZatcaEnvironment : null,
      'sync_status': _sendToZatca ? 'pending' : 'local',
      'created_at': DateTime.now().toIso8601String(),
      // Add company details for ZATCA
      'company': {
        'ownerName1': _companyDetails?.ownerName1 ?? 'Company Name',
        'vatNo': _companyDetails?.vatNo ?? '',
        'crNumber': _companyDetails?.crNumber ?? '',
        'address': _companyDetails?.address ?? '',
        'city': _companyDetails?.city ?? '',
        'phone': _companyDetails?.phone ?? '',
        'email': _companyDetails?.email ?? '',
      },
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
      // Generate QR data using standardized service
      final invoiceData = {
        'no': _invoiceNo,
        'invoice_prefix': _sendToZatca ? 'ZATCA' : 'INV_NO',
        'date': _date,
        'salesman': _salesmanCtrl.text,
        'customer': _customerCtrl.text,
        'customerVat': _customerVatCtrl.text,
        'items': _items.map((it) => it.toMap()).toList(),
        'vatPercent': _vatPercent,
        'discount': double.tryParse(_discountCtrl.text) ?? 0,
        'cash': double.tryParse(_cashCtrl.text) ?? 0,
        'zatca_invoice': _sendToZatca,
        'zatca_environment': _currentZatcaEnvironment,
        'company_name': _companyDetails?.ownerName1 ?? 'Company Name',
        'company_vat': _companyDetails?.vatNo ?? '',
        'company_cr': _companyDetails?.crNumber ?? '',
        'company_address': _companyDetails?.address ?? '',
        'company_city': _companyDetails?.city ?? '',
        'company_phone': _companyDetails?.phone ?? '',
        'company_email': _companyDetails?.email ?? '',
      };

      final qrData = QRService.generatePrintQRData(invoiceData);

      // Calculate totals
      final subtotal = _items.fold<double>(0, (sum, it) => sum + it.quantity * it.rate);
      final discount = double.tryParse(_discountCtrl.text) ?? 0;
      final vatAmount = _items.fold<double>(0, (sum, it) => sum + (it.quantity * it.rate * _vatPercent / 100));
      final total = subtotal + vatAmount - discount;

      // Generate PDF
      final Uint8List pdfBytes = await InvoiceHelper.generatePdf(
        invoiceNumber: '${_sendToZatca ? 'ZATCA' : 'INV_NO'}-${_sendToZatca ? _zatcaInvoiceNo : _localInvoiceNo}',
        invoiceData: invoiceData,
        qrData: qrData,
        customerName: _customerCtrl.text,
        date: _date,
        items: _items.map((item) => item.toMap()).toList(),
        total: total,
        vatAmount: vatAmount,
        subtotal: subtotal,
        discount: discount,
        vatPercent: _vatPercent.toString(),
        companyDetails: _companyDetails?.toMap() ?? {},
        salesman: _salesmanCtrl.text,
        cash: _cashCtrl.text,
        customer: _customerCtrl.text,
        vatNo: _customerVatCtrl.text,
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
      // For ZATCA invoices, show message that QR will be generated after verification
      if (_sendToZatca) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.qr_code, color: Colors.orange),
                SizedBox(width: 8),
                Text('ZATCA Invoice Preview'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This is a ZATCA invoice preview.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  '• QR code will be generated after ZATCA verification',
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  '• Final invoice will include ZATCA UUID for verification',
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  '• Click Print to verify with ZATCA and generate final invoice',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // For local invoices, show preview with QR code
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
          builder: (_) => PreviewInvoiceScreen(
            imageData: imageData,
            isZatcaInvoice: false, // Local invoice
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview error: $e')),
      );
    }
  }

  // FIXED: Print thermal invoice with ZATCA retry mechanism
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

      // If this is a ZATCA invoice, sync with ZATCA BEFORE printing
      if (_sendToZatca) {
        // Show loading dialog with retry info
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('Syncing with ZATCA...'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Please wait while we verify your invoice with ZATCA...'),
                SizedBox(height: 8),
                Text('Attempt: 1/5', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );

        // Generate invoice data for ZATCA sync
        final invoiceData = {
          'no': _invoiceNo,
          'invoice_prefix': _sendToZatca ? 'ZATCA' : 'INV_NO',
          'date': _date,
          'salesman': _salesmanCtrl.text,
          'customer': _customerCtrl.text,
          'vatNo': _customerVatCtrl.text,
          'items': _items.map((it) => it.toMap()).toList(),
          'vatPercent': _vatPercent,
          'discount': double.tryParse(_discountCtrl.text) ?? 0,
          'cash': double.tryParse(_cashCtrl.text) ?? 0,
          'zatca_invoice': _sendToZatca,
          'zatca_environment': _currentZatcaEnvironment,
          'company': {
            'ownerName1': _companyDetails?.ownerName1 ?? 'Company Name',
            'vatNo': _companyDetails?.vatNo ?? '',
            'crNumber': _companyDetails?.crNumber ?? '',
            'address': _companyDetails?.address ?? '',
            'city': _companyDetails?.city ?? '',
            'phone': _companyDetails?.phone ?? '',
            'email': _companyDetails?.email ?? '',
          },
        };

        // ZATCA retry mechanism
        Map<String, dynamic>? zatcaResponse;
        String? lastError;
        
        for (int attempt = 1; attempt <= 5; attempt++) {
          try {
            // Update loading dialog with attempt number
            if (attempt > 1) {
              Navigator.of(context).pop(); // Close previous dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: Text('Retrying ZATCA Sync...'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Attempt: $attempt/5'),
                      if (lastError != null) ...[
                        SizedBox(height: 8),
                        Text('Previous error: ${lastError!.substring(0, lastError!.length > 50 ? 50 : lastError!.length)}...', 
                             style: TextStyle(fontSize: 10, color: Colors.red)),
                      ],
                    ],
                  ),
                ),
              );
            }

            // Try ZATCA sync
            zatcaResponse = await _supabaseService.callZatcaEdgeFunction(invoiceData);
            
            if (zatcaResponse['success'] == true) {
              // ZATCA sync successful
              Navigator.of(context).pop(); // Close loading dialog
              
              // Print with real ZATCA data
              await _printWithZatcaData(invoiceData, zatcaResponse, mockPrinting);
              
              // Save with ZATCA data
              await _saveToHistoryWithZatca(invoiceData, zatcaResponse);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Invoice printed with ZATCA verification!\nUUID: ${zatcaResponse['uuid']}'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 5),
                ),
              );
              
              await _incrementInvoice();
              _resetForm();
              return; // Success - exit function
            } else {
              lastError = zatcaResponse['error'] ?? 'Unknown error';
              print('ZATCA attempt $attempt failed: $lastError');
            }
          } catch (e) {
            lastError = e.toString();
            print('ZATCA attempt $attempt exception: $lastError');
          }
          
          // Wait before retry (except for last attempt)
          if (attempt < 5) {
            await Future.delayed(Duration(seconds: 2));
          }
        }

        // All 5 attempts failed - show detailed error dialog
        Navigator.of(context).pop(); // Close loading dialog
        
        await _showZatcaFailureDialog(lastError ?? 'Unknown error');
        return; // Don't print - ZATCA verification failed

      } else {
        // Local invoice - print normally
        await _printLocalInvoice(mockPrinting);
        await _incrementInvoice();
        _resetForm();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice processed successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Show ZATCA failure dialog with detailed error and guidance
  Future<void> _showZatcaFailureDialog(String error) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('ZATCA Verification Failed'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'All 5 attempts to verify with ZATCA failed.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Error Details:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  error,
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Possible Causes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Network connectivity issues'),
              Text('• ZATCA server temporarily unavailable'),
              Text('• Invalid invoice data format'),
              Text('• ZATCA credentials expired'),
              SizedBox(height: 16),
              Text(
                'Solution:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              SizedBox(height: 8),
              Text(
                'If you still want to print this invoice, please:\n\n1. Turn OFF "Send to ZATCA" toggle\n2. Click Print again\n3. Invoice will print as Local invoice',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Print with ZATCA data
  Future<void> _printWithZatcaData(Map<String, dynamic> invoiceData, Map<String, dynamic> zatcaResponse, bool mockPrinting) async {
    final updatedInvoiceData = {
      ...invoiceData,
      'zatca_uuid': zatcaResponse['uuid'],
      'zatca_qr_code': zatcaResponse['qr_code'],
      'sync_status': 'completed',
    };

    if (mockPrinting) {
      // Show image preview for mock printing with ZATCA data
      final imageData = await _generateInvoiceImageWithZatca(updatedInvoiceData);
      if (imageData != null) {
        await showDialog(
          context: context,
          builder: (context) => Dialog(
            insetPadding: const EdgeInsets.all(10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Invoice Preview Image (Thermal Printer Format)
                    Container(
                      color: Colors.white,
                      child: Image.memory(imageData),
                    ),
                    
                    // ZATCA Information
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Colors.black, width: 1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified, color: Colors.black),
                              SizedBox(width: 8),
                              Text(
                                '✅ ZATCA Verified Invoice',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          
                          // ZATCA Details
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.black, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ZATCA Details:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text('UUID: ${zatcaResponse['uuid'] ?? 'N/A'}', style: TextStyle(color: Colors.black)),
                                Text('Status: ${zatcaResponse['compliance_status'] ?? 'N/A'}', style: TextStyle(color: Colors.black)),
                                Text('Environment: ${updatedInvoiceData['zatca_environment'] ?? 'live'}', style: TextStyle(color: Colors.black)),
                                SizedBox(height: 8),
                                Text(
                                  'QR Code Data:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.black, width: 1),
                                  ),
                                  child: Text(
                                    'Contains ZATCA UUID for verification',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 12),
                          Text(
                            'This invoice is now verified with ZATCA and can be scanned with the ZATCA mobile app.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    } else {
      if (_printerSelectionService.selectedPrinter == null) {
        _showPrinterDialog();
        return;
      }

      // Calculate totals
      final subtotal = _items.fold<double>(0, (sum, it) => sum + it.quantity * it.rate);
      final discount = double.tryParse(_discountCtrl.text) ?? 0;
      final vatAmount = _items.fold<double>(0, (sum, it) => sum + (it.quantity * it.rate * _vatPercent / 100));
      final total = subtotal + vatAmount - discount;

      // Print with real ZATCA data
      await _printerService.printInvoice(
        invoiceNumber: '${_sendToZatca ? 'ZATCA' : 'INV_NO'}-${_sendToZatca ? _zatcaInvoiceNo : _localInvoiceNo}',
        invoiceData: updatedInvoiceData,
        qrData: _sendToZatca 
            ? QRService.generateSimplifiedZatcaQRData(updatedInvoiceData)
            : QRService.generatePrintQRData(updatedInvoiceData),
        customerName: _customerCtrl.text,
        date: _date,
        items: _items.map((item) => item.toMap()).toList(),
        total: total,
        vatAmount: vatAmount,
        subtotal: subtotal,
        discount: double.tryParse(_discountCtrl.text) ?? 0,
        vatPercent: _vatPercent.toString(),
        companyDetails: _companyDetails?.toMap() ?? {},
      );
    }
  }

  // Print local invoice
  Future<void> _printLocalInvoice(bool mockPrinting) async {
    final imageData = await _generateInvoiceImage();
    if (imageData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate invoice image')),
      );
      return;
    }

    if (mockPrinting) {
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(10),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: SingleChildScrollView(
              child: Container(
                color: Colors.white,
                child: Image.memory(imageData),
              ),
            ),
          ),
        ),
      );
    } else {
      if (_printerSelectionService.selectedPrinter == null) {
        _showPrinterDialog();
        return;
      }

      // Calculate totals
      final subtotal = _items.fold<double>(0, (sum, it) => sum + it.quantity * it.rate);
      final discount = double.tryParse(_discountCtrl.text) ?? 0;
      final vatAmount = _items.fold<double>(0, (sum, it) => sum + (it.quantity * it.rate * _vatPercent / 100));
      final total = subtotal + vatAmount - discount;

      await _printerService.printInvoice(
        invoiceNumber: '${_sendToZatca ? 'ZATCA' : 'INV_NO'}-${_sendToZatca ? _zatcaInvoiceNo : _localInvoiceNo}',
        invoiceData: {
          'no': _invoiceNo,
          'invoice_prefix': _sendToZatca ? 'ZATCA' : 'INV_NO',
          'date': _date,
          'salesman': _salesmanCtrl.text,
          'customer': _customerCtrl.text,
          'customerVat': _customerVatCtrl.text,
          'items': _items.map((it) => it.toMap()).toList(),
          'vatPercent': _vatPercent,
          'discount': double.tryParse(_discountCtrl.text) ?? 0,
          'cash': double.tryParse(_cashCtrl.text) ?? 0,
          'zatca_invoice': _sendToZatca,
          'zatca_environment': _currentZatcaEnvironment,
          'company_name': _companyDetails?.ownerName1 ?? 'Company Name',
          'company_vat': _companyDetails?.vatNo ?? '',
          'company_cr': _companyDetails?.crNumber ?? '',
          'company_address': _companyDetails?.address ?? '',
          'company_city': _companyDetails?.city ?? '',
          'company_phone': _companyDetails?.phone ?? '',
          'company_email': _companyDetails?.email ?? '',
        },
        qrData: QRService.generatePrintQRData({
          'no': _invoiceNo,
          'invoice_prefix': _sendToZatca ? 'ZATCA' : 'INV_NO',
          'date': _date,
          'salesman': _salesmanCtrl.text,
          'customer': _customerCtrl.text,
          'customerVat': _customerVatCtrl.text,
          'items': _items.map((it) => it.toMap()).toList(),
          'vatPercent': _vatPercent,
          'discount': double.tryParse(_discountCtrl.text) ?? 0,
          'cash': double.tryParse(_cashCtrl.text) ?? 0,
          'zatca_invoice': _sendToZatca,
          'zatca_environment': _currentZatcaEnvironment,
          'company_name': _companyDetails?.ownerName1 ?? 'Company Name',
          'company_vat': _companyDetails?.vatNo ?? '',
          'company_cr': _companyDetails?.crNumber ?? '',
          'company_address': _companyDetails?.address ?? '',
          'company_city': _companyDetails?.city ?? '',
          'company_phone': _companyDetails?.phone ?? '',
          'company_email': _companyDetails?.email ?? '',
        }),
        customerName: _customerCtrl.text,
        date: _date,
        items: _items.map((item) => item.toMap()).toList(),
        total: total,
        vatAmount: vatAmount,
        subtotal: subtotal,
        discount: double.tryParse(_discountCtrl.text) ?? 0,
        vatPercent: _vatPercent.toString(),
        companyDetails: _companyDetails?.toMap() ?? {},
      );
    }
  }

  // Save invoice with ZATCA data
  Future<void> _saveToHistoryWithZatca(Map<String, dynamic> invoiceData, Map<String, dynamic> zatcaResponse) async {
    // Determine invoice number based on ZATCA toggle
    final invoiceNumber = _sendToZatca ? _zatcaInvoiceNo : _localInvoiceNo;
    final invoicePrefix = _sendToZatca ? 'ZATCA' : 'INV_NO';
    
    // Calculate totals
    final subtotal = _items.fold<double>(0, (sum, it) => sum + it.quantity * it.rate);
    final discount = double.tryParse(_discountCtrl.text) ?? 0;
    final vatAmount = _items.fold<double>(0, (sum, it) => sum + (it.quantity * it.rate * _vatPercent / 100));
    final total = subtotal + vatAmount - discount;
    
    final record = {
      'no': invoiceNumber,
      'invoice_prefix': invoicePrefix,
      'date': _date,
      'salesman': _salesmanCtrl.text,
      'customer': _customerCtrl.text,
      'vatNo': _customerVatCtrl.text,
      'items': _items.map((it) => it.toMap()).toList(),
      'vatPercent': _vatPercent,
      'discount': discount,
      'cash': double.tryParse(_cashCtrl.text) ?? 0,
      'total': total,
      'vatAmount': vatAmount,
      'subtotal': subtotal,
      'zatca_invoice': _sendToZatca,
      'zatca_environment': _sendToZatca ? _currentZatcaEnvironment : null,
      'sync_status': 'completed', // Already synced
      'created_at': DateTime.now().toIso8601String(),
      'synced_at': DateTime.now().toIso8601String(),
      // ZATCA data
      'zatca_uuid': zatcaResponse['uuid'],
      'zatca_qr_code': zatcaResponse['qr_code'],
      'zatca_response': jsonEncode(zatcaResponse),
      // Company details
      'company': invoiceData['company'],
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

  // Generate invoice image with ZATCA data
  Future<Uint8List?> _generateInvoiceImageWithZatca(Map<String, dynamic> invoiceData) async {
    try {
      // Calculate totals
      final subtotal = _items.fold<double>(0, (sum, it) => sum + it.quantity * it.rate);
      final discount = double.tryParse(_discountCtrl.text) ?? 0;
      final vatAmount = _items.fold<double>(0, (sum, it) => sum + (it.quantity * it.rate * _vatPercent / 100));
      final total = subtotal + vatAmount - discount;

      // Generate PDF with ZATCA data
      final Uint8List pdfBytes = await InvoiceHelper.generatePdf(
        invoiceNumber: '${_sendToZatca ? 'ZATCA' : 'INV_NO'}-${_sendToZatca ? _zatcaInvoiceNo : _localInvoiceNo}',
        invoiceData: invoiceData,
        qrData: _sendToZatca 
            ? QRService.generateSimplifiedZatcaQRData(invoiceData)
            : QRService.generatePrintQRData(invoiceData), // Use existing QR data for local invoices
        customerName: _customerCtrl.text,
        date: _date,
        items: _items.map((item) => item.toMap()).toList(),
        total: total,
        vatAmount: vatAmount,
        subtotal: subtotal,
        discount: discount,
        vatPercent: _vatPercent.toString(),
        companyDetails: _companyDetails?.toMap() ?? {},
        salesman: _salesmanCtrl.text,
        cash: _cashCtrl.text,
        customer: _customerCtrl.text,
        vatNo: _customerVatCtrl.text,
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
      print('Error generating invoice image with ZATCA: $e');
      return null;
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
                                  'Invoice Number: ${_sendToZatca ? "ZATCA-$_zatcaInvoiceNo" : "INV_NO-$_localInvoiceNo"}',
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