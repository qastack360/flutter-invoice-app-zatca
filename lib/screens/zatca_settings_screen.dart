import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

class ZatcaSettingsScreen extends StatefulWidget {
  final ValueNotifier<bool> refreshNotifier;

  const ZatcaSettingsScreen({Key? key, required this.refreshNotifier}) : super(key: key);

  @override
  _ZatcaSettingsScreenState createState() => _ZatcaSettingsScreenState();
}

class _ZatcaSettingsScreenState extends State<ZatcaSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vatNumberController = TextEditingController();
  final _crNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  String _selectedEnvironment = 'sandbox';

  @override
  void initState() {
    super.initState();
    _loadZatcaSettings();
  }

  @override
  void dispose() {
    _vatNumberController.dispose();
    _crNumberController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadZatcaSettings() async {
    try {
      // First load from local storage as fallback
      final prefs = await SharedPreferences.getInstance();
      final localEnvironment = prefs.getString('zatcaEnvironment') ?? 'sandbox';
      
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) {
        setState(() {
          _selectedEnvironment = localEnvironment;
          _isLoading = false;
        });
        return;
      }

      final response = await _supabaseService.client
          .from('zatca_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _vatNumberController.text = response['vat_number'] ?? '';
          _crNumberController.text = response['cr_number'] ?? '';
          _addressController.text = response['address'] ?? '';
          _cityController.text = response['city'] ?? '';
          _phoneController.text = response['phone'] ?? '';
          _emailController.text = response['email'] ?? '';
          _selectedEnvironment = response['environment'] ?? localEnvironment;
          _isLoading = false;
        });
      } else {
        setState(() {
          _selectedEnvironment = localEnvironment;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading ZATCA settings: $e');
      setState(() {
        _isLoading = false;
      });
      // Ignore error if no settings found
    }
  }

  Future<void> _saveZatcaSettings() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final settings = {
        'user_id': userId,
        'vat_number': _vatNumberController.text,
        'cr_number': _crNumberController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'environment': _selectedEnvironment,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabaseService.client
          .from('zatca_settings')
          .upsert(settings, onConflict: 'user_id')
          .select();

      // Also save environment to local storage for invoice creation
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('zatcaEnvironment', _selectedEnvironment);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ZATCA settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      widget.refreshNotifier.value = !widget.refreshNotifier.value;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving ZATCA settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ZATCA Settings / إعدادات ضريبة القيمة المضافة'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveZatcaSettings,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ZATCA Configuration / تكوين ضريبة القيمة المضافة',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              value: _selectedEnvironment,
                              decoration: InputDecoration(
                                labelText: 'Environment / البيئة *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.cloud),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'sandbox',
                                  child: Text('Sandbox (Testing)'),
                                ),
                                DropdownMenuItem(
                                  value: 'production',
                                  child: Text('Production (Live)'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedEnvironment = value!;
                                });
                              },
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _vatNumberController,
                              decoration: InputDecoration(
                                labelText: 'ZATCA VAT Number / الرقم الضريبي لضريبة القيمة المضافة *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.numbers),
                                helperText: '15-digit VAT number',
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Please enter ZATCA VAT number';
                                }
                                if (value!.length != 15) {
                                  return 'VAT number must be 15 digits';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _crNumberController,
                              decoration: InputDecoration(
                                labelText: 'CR Number / رقم السجل التجاري',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.business),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _addressController,
                              decoration: InputDecoration(
                                labelText: 'Address / العنوان',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.location_on),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _cityController,
                              decoration: InputDecoration(
                                labelText: 'City / المدينة',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.location_city),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: 'Phone / الهاتف',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email / البريد الإلكتروني',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _saveZatcaSettings,
                                icon: Icon(Icons.save),
                                label: Text('Save ZATCA Settings / حفظ إعدادات ضريبة القيمة المضافة'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Important Notes / ملاحظات مهمة',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            ListTile(
                              leading: Icon(Icons.warning, color: Colors.orange),
                              title: Text('Environment Selection'),
                              subtitle: Text('Use Sandbox for testing and Production for live invoices.'),
                            ),
                            ListTile(
                              leading: Icon(Icons.warning, color: Colors.orange),
                              title: Text('VAT Number'),
                              subtitle: Text('Must be a valid 15-digit Saudi VAT number.'),
                            ),
                            ListTile(
                              leading: Icon(Icons.warning, color: Colors.orange),
                              title: Text('Data Accuracy'),
                              subtitle: Text('Ensure all information is accurate for ZATCA compliance.'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 