import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final SupabaseClient _supabase;
  final _uuid = Uuid();

  // Initialize Supabase client
  Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://layidhpzfoyukkmvnnpf.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxheWlkaHB6Zm95dWtrbXZubnBmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM2ODUyODEsImV4cCI6MjA2OTI2MTI4MX0.M4YlblXs6jztN42dZ97oFyffioqJrO7liLcvVdkLMew',
    );
    _supabase = Supabase.instance.client;
    await _createDefaultAdminUser();
  }

  // Create default admin user if not exists
  Future<void> _createDefaultAdminUser() async {
    final email = 'admin@mail.com';
    final password = 'admin';
    try {
      final response = await _supabase.auth.signInWithPassword(email: email, password: password);
      if (response.user == null) {
        // User does not exist, create it
        await _supabase.auth.signUp(email: email, password: password);
      }
    } catch (e) {
      // Ignore error if user already exists or if 404
    }
  }

  SupabaseClient get client => _supabase;

  // Check if user is authenticated
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Sign in with email and password
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      if (e.toString().contains('404')) {
        throw Exception('User not found. Please check your email or sign up.');
      }
      throw Exception('Login failed: $e');
    }
  }

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    try {
      return await _supabase.auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      if (e.toString().contains('404')) {
        throw Exception('Signup failed. Please try again later.');
      }
      throw Exception('Signup failed: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Save invoice to Supabase
  Future<Map<String, dynamic>> saveInvoice(Map<String, dynamic> invoiceData) async {
    try {
      final response = await _supabase
          .from('invoices')
          .insert({
            'invoice_number': invoiceData['no'],
            'invoice_date': invoiceData['date'],
            'customer_name': invoiceData['customer'],
            'salesman': invoiceData['salesman'],
            'vat_number': invoiceData['vatNo'],
            'total_amount': invoiceData['total'],
            'vat_amount': invoiceData['vatAmount'],
            'items': jsonEncode(invoiceData['items']),
            'company_details': jsonEncode(invoiceData['company']),
            'sync_status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to save invoice: $e');
    }
  }

  // Save company details to Supabase
  Future<Map<String, dynamic>> saveCompanyDetails(Map<String, dynamic> companyData) async {
    try {
      // Check if company details already exist
      final existing = await _supabase
          .from('company_details')
          .select()
          .eq('user_id', _supabase.auth.currentUser?.id ?? 'default')
          .maybeSingle();

      Map<String, dynamic> response;
      
      if (existing != null) {
        // Update existing record
        response = await _supabase
            .from('company_details')
            .update({
              'owner_name1': companyData['ownerName1'] ?? '',
              'owner_name2': companyData['ownerName2'] ?? '',
              'other_name': companyData['otherName'] ?? '',
              'phone': companyData['phone'] ?? '',
              'vat_no': companyData['vatNo'] ?? '',
              'cr_number': companyData['crNumber'] ?? '',
              'address': companyData['address'] ?? '',
              'city': companyData['city'] ?? '',
              'email': companyData['email'] ?? '',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', _supabase.auth.currentUser?.id ?? 'default')
            .select()
            .single();
      } else {
        // Insert new record
        response = await _supabase
            .from('company_details')
            .insert({
              'user_id': _supabase.auth.currentUser?.id ?? 'default',
              'owner_name1': companyData['ownerName1'] ?? '',
              'owner_name2': companyData['ownerName2'] ?? '',
              'other_name': companyData['otherName'] ?? '',
              'phone': companyData['phone'] ?? '',
              'vat_no': companyData['vatNo'] ?? '',
              'cr_number': companyData['crNumber'] ?? '',
              'address': companyData['address'] ?? '',
              'city': companyData['city'] ?? '',
              'email': companyData['email'] ?? '',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
      }

      return response;
    } catch (e) {
      throw Exception('Failed to save company details: $e');
    }
  }

  // Load company details from Supabase
  Future<Map<String, dynamic>?> loadCompanyDetails() async {
    try {
      final response = await _supabase
          .from('company_details')
          .select()
          .eq('user_id', _supabase.auth.currentUser?.id ?? 'default')
          .maybeSingle();

      if (response != null) {
        return {
          'ownerName1': response['owner_name1'] ?? '',
          'ownerName2': response['owner_name2'] ?? '',
          'otherName': response['other_name'] ?? '',
          'phone': response['phone'] ?? '',
          'vatNo': response['vat_no'] ?? '',
          'crNumber': response['cr_number'] ?? '',
          'address': response['address'] ?? '',
          'city': response['city'] ?? '',
          'email': response['email'] ?? '',
        };
      }
      return null;
    } catch (e) {
      print('Error loading company details: $e');
      return null;
    }
  }

  // Load all invoices from Supabase
  Future<List<Map<String, dynamic>>> loadInvoices() async {
    try {
      final response = await _supabase
          .from('invoices')
          .select()
          .eq('user_id', _supabase.auth.currentUser?.id ?? 'default')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error loading invoices: $e');
      return [];
    }
  }

  // Save ZATCA invoice to Supabase
  Future<Map<String, dynamic>> saveZatcaInvoice(Map<String, dynamic> invoiceData) async {
    try {
      final response = await _supabase
          .from('invoices')
          .insert({
            'user_id': _supabase.auth.currentUser?.id ?? 'default',
            'invoice_number': invoiceData['no'],
            'invoice_prefix': invoiceData['invoice_prefix'],
            'invoice_date': invoiceData['date'],
            'customer_name': invoiceData['customer'],
            'salesman': invoiceData['salesman'],
            'vat_number': invoiceData['vatNo'],
            'total_amount': invoiceData['total'],
            'vat_amount': invoiceData['vatAmount'],
            'subtotal': invoiceData['subtotal'],
            'discount': invoiceData['discount'],
            'cash': invoiceData['cash'],
            'items': jsonEncode(invoiceData['items']),
            'company_details': jsonEncode(invoiceData['company']),
            'zatca_invoice': true,
            'zatca_uuid': invoiceData['zatca_uuid'],
            'zatca_environment': invoiceData['zatca_environment'],
            'zatca_response': jsonEncode(invoiceData['zatca_response']),
            'sync_status': 'completed',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to save ZATCA invoice: $e');
    }
  }

  // Delete invoice from Supabase
  Future<void> deleteInvoice(String invoiceId) async {
    try {
      await _supabase
          .from('invoices')
          .delete()
          .eq('id', invoiceId)
          .eq('user_id', _supabase.auth.currentUser?.id ?? 'default');
    } catch (e) {
      throw Exception('Failed to delete invoice: $e');
    }
  }

  // Get all invoices from Supabase
  Future<List<Map<String, dynamic>>> getAllInvoices() async {
    try {
      final response = await _supabase
          .from('invoices')
          .select()
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch invoices: $e');
    }
  }

  // Update invoice sync status
  Future<void> updateInvoiceSyncStatus(int invoiceId, String status, {String? zatcaResponse}) async {
    try {
      await _supabase
          .from('invoices')
          .update({
            'sync_status': status,
            'zatca_response': zatcaResponse,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invoiceId);
    } catch (e) {
      throw Exception('Failed to update sync status: $e');
    }
  }

  // Get pending sync invoices
  Future<List<Map<String, dynamic>>> getPendingSyncInvoices() async {
    try {
      final response = await _supabase
          .from('invoices')
          .select()
          .eq('sync_status', 'pending')
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch pending invoices: $e');
    }
  }

  // Call ZATCA Edge Function
  Future<Map<String, dynamic>> callZatcaEdgeFunction(Map<String, dynamic> invoiceData) async {
    try {
      final response = await _supabase.functions.invoke(
        'zatca-invoice-processor',
        body: {
          'invoice': invoiceData,
          'request_id': _uuid.v4(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (response.status != 200) {
        throw Exception('Edge function failed: ${response.data}');
      }

      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception('Failed to call ZATCA function: $e');
    }
  }

  // Save sync log
  Future<void> saveSyncLog(String action, String status, String details) async {
    try {
      await _supabase
          .from('sync_logs')
          .insert({
            'action': action,
            'status': status,
            'details': details,
            'timestamp': DateTime.now().toIso8601String(),
            'user_id': currentUser?.id,
          });
    } catch (e) {
      // Log error but don't throw to avoid breaking sync process
      print('Failed to save sync log: $e');
    }
  }

  // Get sync logs
  Future<List<Map<String, dynamic>>> getSyncLogs() async {
    try {
      final response = await _supabase
          .from('sync_logs')
          .select()
          .order('timestamp', ascending: false)
          .limit(100);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch sync logs: $e');
    }
  }

  // Check connectivity
  Future<bool> checkConnectivity() async {
    try {
      await _supabase.from('invoices').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Generate invoice hash for ZATCA
  String generateInvoiceHash(Map<String, dynamic> invoiceData) {
    // Create a standardized string for hashing
    final invoiceString = '''
      ${invoiceData['no']}
      ${invoiceData['date']}
      ${invoiceData['customer']}
      ${invoiceData['vatNo']}
      ${invoiceData['total']}
      ${invoiceData['vatAmount']}
    '''.trim();

    // Generate SHA-256 hash
    final bytes = utf8.encode(invoiceString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Validate ZATCA response
  bool validateZatcaResponse(Map<String, dynamic> response) {
    return response.containsKey('success') && 
           response.containsKey('uuid') && 
           response.containsKey('qr_code');
  }

  // Printer status management
  Future<void> updatePrinterStatus({
    required String? printerMac,
    required String? printerName,
    required bool isConnected,
  }) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.rpc('update_printer_connection', params: {
        'user_uuid': userId,
        'printer_mac': printerMac,
        'printer_name': printerName,
        'is_connected': isConnected,
      });
    } catch (e) {
      throw Exception('Error updating printer status: $e');
    }
  }

  // Get printer connection status
  Future<Map<String, dynamic>> getPrinterStatus() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase.rpc('get_printer_status', params: {
        'user_uuid': userId,
      });

      if (response != null && response.isNotEmpty) {
        return response[0] as Map<String, dynamic>;
      }
      
      return {
        'is_connected': false,
        'printer_name': null,
        'printer_mac': null,
        'last_connected': null,
        'connection_attempts': 0,
      };
    } catch (e) {
      throw Exception('Error getting printer status: $e');
    }
  }

  // Log print activity
  Future<void> logPrintActivity({
    required String invoiceId,
    required int invoiceNumber,
    required String printStatus,
    String? printerMac,
    String? errorMessage,
  }) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.rpc('log_print_activity', params: {
        'user_uuid': userId,
        'invoice_id': invoiceId,
        'invoice_number': invoiceNumber,
        'print_status': printStatus,
        'printer_mac': printerMac,
        'error_message': errorMessage,
      });
    } catch (e) {
      throw Exception('Error logging print activity: $e');
    }
  }

  // Save invoice preview
  Future<void> saveInvoicePreview({
    required String invoiceId,
    required int invoiceNumber,
    required String invoicePrefix,
    required Map<String, dynamic> previewData,
  }) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.from('invoice_previews').upsert({
        'user_id': userId,
        'invoice_id': invoiceId,
        'invoice_number': invoiceNumber,
        'invoice_prefix': invoicePrefix,
        'preview_data': previewData,
      });
    } catch (e) {
      throw Exception('Error saving invoice preview: $e');
    }
  }
} 