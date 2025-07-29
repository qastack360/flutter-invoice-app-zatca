import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../db/database_helper.dart';
import '../models/company_details.dart';

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
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _loadCompanyDetails();
  }

  Future<void> _loadCompanyDetails() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('company_details', where: 'id=1');
    if (rows.isNotEmpty) {
      final company = CompanyDetails.fromMap(rows.first);
      setState(() {
        _owner1Ctrl.text = company.ownerName1;
        _owner2Ctrl.text = company.ownerName2;
        _otherCtrl.text = company.otherName;
        _phoneCtrl.text = company.phone;
        _vatCtrl.text = company.vatNo;
      });
    }
  }

  Future<void> _saveCompany() async {
    final company = CompanyDetails(
      id: 1,
      ownerName1: _owner1Ctrl.text,
      ownerName2: _owner2Ctrl.text,
      otherName: _otherCtrl.text,
      phone: _phoneCtrl.text,
      vatNo: _vatCtrl.text,
    );

    final dbHelper = DatabaseHelper.instance;
    await dbHelper.updateCompany(company);

    // Trigger refresh
    widget.refreshNotifier.value = !widget.refreshNotifier.value;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Company details saved successfully!')),
    );
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
        title: const Text('Company Details'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: _owner1Ctrl,
              decoration: const InputDecoration(labelText: 'Owner Name 1'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _owner2Ctrl,
              decoration: const InputDecoration(labelText: 'Owner Name 2'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _otherCtrl,
              decoration: const InputDecoration(labelText: 'Other Name'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _vatCtrl,
              decoration: const InputDecoration(labelText: 'Company VAT No'),
            ),
            const SizedBox(height: 24),
            // Logo upload section
            if (_logoPath != null && _logoPath!.isNotEmpty)
              Image.file(File(_logoPath!), height: 100),
            ElevatedButton(
              onPressed: _pickLogo,
              child: const Text('Upload Logo'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveCompany,
              child: const Text('Save Company Details'),
            ),
          ],
        ),
      ),
    );
  }
}