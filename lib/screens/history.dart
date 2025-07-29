import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../models/company_details.dart';
import '../models/item_data.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/printer_service.dart';
import '../services/sync_service.dart';
import '../services/supabase_service.dart';
import 'package:flutter/foundation.dart';

class HistoryScreen extends StatefulWidget {
  final ValueNotifier<bool> refreshNotifier;

  const HistoryScreen({Key? key, required this.refreshNotifier}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _allInvoices = [];
  List<Map<String, dynamic>> _filteredInvoices = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  final _searchCtrl = TextEditingController();
  final BluetoothPrinterService _printerService = BluetoothPrinterService();
  final PrinterService _printerSelectionService = PrinterService();
  final SyncService _syncService = SyncService();
  final SupabaseService _supabaseService = SupabaseService();
  bool _mockPrinting = kDebugMode;
  SyncStats? _syncStats;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
    _loadSyncStats();
    widget.refreshNotifier.addListener(_loadInvoices);
    _loadMockPrintingSetting();
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_loadInvoices);
    super.dispose();
  }

  Future<void> _loadMockPrintingSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mockPrinting = prefs.getBool('mockPrinting') ?? false;
    });
  }

  Future<void> _loadInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('invoices') ?? [];
    setState(() {
      _allInvoices = data.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
      _filteredInvoices = List.from(_allInvoices);
      _isLoading = false;
    });
    await _loadSyncStats();
  }

  Future<void> _loadSyncStats() async {
    try {
      final stats = await _syncService.getSyncStats();
      setState(() {
        _syncStats = stats;
      });
    } catch (e) {
      print('Failed to load sync stats: $e');
    }
  }

  void _search(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredInvoices = List.from(_allInvoices);
      } else {
        _filteredInvoices = _allInvoices.where((inv) {
          return inv['no'].toString().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _syncInvoices() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await _syncService.syncAllInvoices();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
          duration: Duration(seconds: 3),
        ),
      );

      // Reload data after sync
      await _loadInvoices();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _retryFailedInvoices() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await _syncService.retryFailedInvoices();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );

      await _loadInvoices();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Retry failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _printThermalInvoice(Map<String, dynamic> invoice) async {
    try {
      final qrData = jsonEncode(invoice);

      if (!_mockPrinting) {
        final printer = _printerSelectionService.selectedPrinter;
        if (printer == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No printer selected!')),
          );
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice processed successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<CompanyDetails?> _getCompanyDetails() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('company_details', where: 'id=1');
    if (rows.isNotEmpty) {
      return CompanyDetails.fromMap(rows.first);
    }
    return null;
  }

  Widget _buildSyncStatusCard() {
    if (_syncStats == null) return SizedBox.shrink();

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sync Status / حالة المزامنة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                _isSyncing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.sync, color: Colors.green),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _buildSyncStat('Total', _syncStats!.total, Colors.blue),
                SizedBox(width: 16),
                _buildSyncStat('Pending', _syncStats!.pending, Colors.orange),
                SizedBox(width: 16),
                _buildSyncStat('Completed', _syncStats!.completed, Colors.green),
                SizedBox(width: 16),
                _buildSyncStat('Failed', _syncStats!.failed, Colors.red),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _syncInvoices,
                    icon: Icon(Icons.sync),
                    label: Text('Sync All / مزامنة الكل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                if (_syncStats!.failed > 0)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSyncing ? null : _retryFailedInvoices,
                      icon: Icon(Icons.refresh),
                      label: Text('Retry Failed / إعادة المحاولة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStat(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice, int index) {
    final dateParts = invoice['date'].split(' – ');
    final date = dateParts[0];
    final time = dateParts.length > 1 ? dateParts[1] : '';
    final syncStatus = invoice['sync_status'] ?? 'pending';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (syncStatus) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Synced';
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Failed';
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = 'Syncing';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        statusText = 'Pending';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.yellow[700],
          child: Text(
            '${index + 1}',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Invoice #${invoice['no']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Icon(statusIcon, color: statusColor, size: 20),
            SizedBox(width: 4),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Customer / العميل: ${invoice['customer']}'),
            const SizedBox(height: 4),
            Text('Date / التاريخ: $date'),
            if (time.isNotEmpty) Text('Time / الوقت: $time'),
            const SizedBox(height: 8),
            Text(
              'Items / العناصر: ${invoice['items'].length}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (invoice['zatca_response'] != null) ...[
              SizedBox(height: 4),
              Text(
                'ZATCA: ${invoice['zatca_uuid'] ?? 'Processed'}',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.print, size: 32, color: Colors.blue),
          onPressed: () => _printThermalInvoice(invoice),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice History / سجل الفواتير'),
        backgroundColor: Colors.yellow,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvoices,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSyncStatusCard(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _search,
              decoration: InputDecoration(
                labelText: 'Search by Invoice # / البحث برقم الفاتورة',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          if (!_mockPrinting) ...[
            Column(
              children: [
                if (_printerSelectionService.selectedPrinter != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Printer: ${_printerSelectionService.selectedPrinter!.name}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (_printerSelectionService.selectedPrinter == null)
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a printer in Create Invoice screen')),
                      );
                    },
                    child: const Text('No printer selected'),
                  ),
                StreamBuilder<BluetoothConnectionState>(
                  stream: _printerSelectionService.selectedPrinter?.connectionState,
                  initialData: BluetoothConnectionState.disconnected,
                  builder: (c, snapshot) {
                    final state = snapshot.data;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Status: ${state?.toString().split('.').last ?? 'N/A'}',
                        style: TextStyle(
                          color: state == BluetoothConnectionState.connected
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                ? const Center(child: Text('No invoices found / لم يتم العثور على فواتير', style: TextStyle(fontSize: 18)))
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _filteredInvoices.length,
              itemBuilder: (context, index) {
                final invoice = _filteredInvoices[index];
                return _buildInvoiceCard(invoice, index);
              },
            ),
          ),
        ],
      ),
    );
  }
}