import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company_details.dart';
import '../services/supabase_service.dart';

class CompanyDetailsScreen extends StatefulWidget {
  final ValueNotifier<bool> refreshNotifier;

  const CompanyDetailsScreen({Key? key, required this.refreshNotifier}) : super(key: key);

  @override
  _CompanyDetailsScreenState createState() => _CompanyDetailsScreenState();
}

class _CompanyDetailsScreenState extends State<CompanyDetailsScreen> {
  final _owner1Ctrl = TextEditingController();
  final _owner2Ctrl = TextEditingController();
  final _otherCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _vatCtrl = TextEditingController();
  final _crCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _logoPath;
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadCompanyDetails();
  }

  Future<void> _loadCompanyDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _owner1Ctrl.text = prefs.getString('company_owner1') ?? '';
        _owner2Ctrl.text = prefs.getString('company_owner2') ?? '';
        _otherCtrl.text = prefs.getString('company_other') ?? '';
        _phoneCtrl.text = prefs.getString('company_phone') ?? '';
        _vatCtrl.text = prefs.getString('company_vat') ?? '';
        _crCtrl.text = prefs.getString('company_cr') ?? '';
        _addressCtrl.text = prefs.getString('company_address') ?? '';
        _cityCtrl.text = prefs.getString('company_city') ?? '';
        _emailCtrl.text = prefs.getString('company_email') ?? '';
      });
    } catch (e) {
      print('Error loading company details: $e');
    }
  }

  Future<void> _saveCompany() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('company_owner1', _owner1Ctrl.text);
      await prefs.setString('company_owner2', _owner2Ctrl.text);
      await prefs.setString('company_other', _otherCtrl.text);
      await prefs.setString('company_phone', _phoneCtrl.text);
      await prefs.setString('company_vat', _vatCtrl.text);
      await prefs.setString('company_cr', _crCtrl.text);
      await prefs.setString('company_address', _addressCtrl.text);
      await prefs.setString('company_city', _cityCtrl.text);
      await prefs.setString('company_email', _emailCtrl.text);

      // Trigger refresh
      widget.refreshNotifier.value = !widget.refreshNotifier.value;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company details saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving company details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _logoPath = pickedFile.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Details / تفاصيل الشركة'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: _owner1Ctrl,
              decoration: const InputDecoration(
                labelText: 'Owner Name 1 / اسم المالك الأول',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _owner2Ctrl,
              decoration: const InputDecoration(
                labelText: 'Owner Name 2 / اسم المالك الثاني',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _otherCtrl,
              decoration: const InputDecoration(
                labelText: 'Other Name / اسم آخر',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone / الهاتف',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _vatCtrl,
              decoration: const InputDecoration(
                labelText: 'Company VAT No / الرقم الضريبي للشركة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _crCtrl,
              decoration: const InputDecoration(
                labelText: 'CR Number / رقم السجل التجاري',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address / العنوان',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityCtrl,
              decoration: const InputDecoration(
                labelText: 'City / المدينة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email / البريد الإلكتروني',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            // Logo upload section
            if (_logoPath != null && _logoPath!.isNotEmpty)
              Image.file(File(_logoPath!), height: 100),
            ElevatedButton(
              onPressed: _pickLogo,
              child: const Text('Upload Logo / تحميل الشعار'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveCompany,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Save Company Details / حفظ تفاصيل الشركة',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}