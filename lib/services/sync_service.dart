import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../db/database_helper.dart';
import 'supabase_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Sync status constants
  static const String SYNC_PENDING = 'pending';
  static const String SYNC_IN_PROGRESS = 'in_progress';
  static const String SYNC_COMPLETED = 'completed';
  static const String SYNC_FAILED = 'failed';

  // Check if device is online
  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Get all local invoices that need syncing
  Future<List<Map<String, dynamic>>> getLocalInvoicesForSync() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('invoices') ?? [];
    
    List<Map<String, dynamic>> unsyncedInvoices = [];
    
    for (String invoiceJson in data) {
      final invoice = jsonDecode(invoiceJson) as Map<String, dynamic>;
      
      // Check if invoice has sync status
      if (invoice['sync_status'] == null || 
          invoice['sync_status'] == SYNC_PENDING ||
          invoice['sync_status'] == SYNC_FAILED) {
        unsyncedInvoices.add(invoice);
      }
    }
    
    return unsyncedInvoices;
  }

  // Sync all pending invoices
  Future<SyncResult> syncAllInvoices() async {
    if (!await isOnline()) {
      return SyncResult(
        success: false,
        message: 'No internet connection available',
        syncedCount: 0,
        failedCount: 0,
      );
    }

    try {
      final invoices = await getLocalInvoicesForSync();
      
      if (invoices.isEmpty) {
        return SyncResult(
          success: true,
          message: 'No invoices to sync',
          syncedCount: 0,
          failedCount: 0,
        );
      }

      int syncedCount = 0;
      int failedCount = 0;
      List<String> errors = [];

      for (Map<String, dynamic> invoice in invoices) {
        try {
          // Mark invoice as in progress
          await _updateLocalInvoiceSyncStatus(invoice, SYNC_IN_PROGRESS);

          // Save to Supabase
          final supabaseInvoice = await _supabaseService.saveInvoice(invoice);

          // Call ZATCA Edge Function
          final zatcaResponse = await _supabaseService.callZatcaEdgeFunction(invoice);

          if (_supabaseService.validateZatcaResponse(zatcaResponse)) {
            // Update local invoice with success status
            await _updateLocalInvoiceSyncStatus(
              invoice, 
              SYNC_COMPLETED,
              zatcaResponse: jsonEncode(zatcaResponse),
            );

            // Update Supabase with ZATCA response
            await _supabaseService.updateInvoiceSyncStatus(
              supabaseInvoice['id'],
              SYNC_COMPLETED,
              zatcaResponse: jsonEncode(zatcaResponse),
            );

            syncedCount++;
            
            // Log success
            await _supabaseService.saveSyncLog(
              'invoice_sync',
              'success',
              'Invoice ${invoice['no']} synced successfully with ZATCA',
            );
          } else {
            throw Exception('Invalid ZATCA response');
          }
        } catch (e) {
          failedCount++;
          errors.add('Invoice ${invoice['no']}: $e');
          
          // Mark invoice as failed
          await _updateLocalInvoiceSyncStatus(invoice, SYNC_FAILED);
          
          // Log error
          await _supabaseService.saveSyncLog(
            'invoice_sync',
            'error',
            'Invoice ${invoice['no']} failed: $e',
          );
        }
      }

      return SyncResult(
        success: failedCount == 0,
        message: failedCount == 0 
          ? 'All invoices synced successfully' 
          : 'Some invoices failed to sync',
        syncedCount: syncedCount,
        failedCount: failedCount,
        errors: errors,
      );

    } catch (e) {
      await _supabaseService.saveSyncLog(
        'sync_process',
        'error',
        'Sync process failed: $e',
      );

      return SyncResult(
        success: false,
        message: 'Sync process failed: $e',
        syncedCount: 0,
        failedCount: 0,
        errors: [e.toString()],
      );
    }
  }

  // Update local invoice sync status
  Future<void> _updateLocalInvoiceSyncStatus(
    Map<String, dynamic> invoice, 
    String status, 
    {String? zatcaResponse}
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('invoices') ?? [];
    
    // Find and update the specific invoice
    for (int i = 0; i < data.length; i++) {
      final storedInvoice = jsonDecode(data[i]) as Map<String, dynamic>;
      
      if (storedInvoice['no'] == invoice['no'] && 
          storedInvoice['date'] == invoice['date']) {
        
        storedInvoice['sync_status'] = status;
        storedInvoice['sync_timestamp'] = DateTime.now().toIso8601String();
        
        if (zatcaResponse != null) {
          storedInvoice['zatca_response'] = zatcaResponse;
        }
        
        data[i] = jsonEncode(storedInvoice);
        break;
      }
    }
    
    await prefs.setStringList('invoices', data);
  }

  // Get sync statistics
  Future<SyncStats> getSyncStats() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('invoices') ?? [];
    
    int total = data.length;
    int pending = 0;
    int completed = 0;
    int failed = 0;
    int inProgress = 0;
    
    for (String invoiceJson in data) {
      final invoice = jsonDecode(invoiceJson) as Map<String, dynamic>;
      final status = invoice['sync_status'] ?? SYNC_PENDING;
      
      switch (status) {
        case SYNC_PENDING:
          pending++;
          break;
        case SYNC_COMPLETED:
          completed++;
          break;
        case SYNC_FAILED:
          failed++;
          break;
        case SYNC_IN_PROGRESS:
          inProgress++;
          break;
      }
    }
    
    return SyncStats(
      total: total,
      pending: pending,
      completed: completed,
      failed: failed,
      inProgress: inProgress,
    );
  }

  // Retry failed invoices
  Future<SyncResult> retryFailedInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('invoices') ?? [];
    
    List<Map<String, dynamic>> failedInvoices = [];
    
    for (String invoiceJson in data) {
      final invoice = jsonDecode(invoiceJson) as Map<String, dynamic>;
      
      if (invoice['sync_status'] == SYNC_FAILED) {
        // Reset to pending for retry
        invoice['sync_status'] = SYNC_PENDING;
        failedInvoices.add(invoice);
      }
    }
    
    if (failedInvoices.isEmpty) {
      return SyncResult(
        success: true,
        message: 'No failed invoices to retry',
        syncedCount: 0,
        failedCount: 0,
      );
    }
    
    // Update local storage
    await prefs.setStringList('invoices', data);
    
    // Sync again
    return await syncAllInvoices();
  }

  // Clear sync logs (for cleanup)
  Future<void> clearSyncLogs() async {
    try {
      await _supabaseService.client
          .from('sync_logs')
          .delete()
          .lt('timestamp', DateTime.now().subtract(Duration(days: 30)).toIso8601String());
    } catch (e) {
      print('Failed to clear sync logs: $e');
    }
  }
}

// Result classes for sync operations
class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;
  final List<String> errors;

  SyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.failedCount,
    this.errors = const [],
  });
}

class SyncStats {
  final int total;
  final int pending;
  final int completed;
  final int failed;
  final int inProgress;

  SyncStats({
    required this.total,
    required this.pending,
    required this.completed,
    required this.failed,
    required this.inProgress,
  });

  double get completionPercentage {
    if (total == 0) return 0.0;
    return (completed / total) * 100;
  }
} 