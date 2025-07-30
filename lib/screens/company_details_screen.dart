import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/company_details.dart';

class CompanyDetailsScreen extends StatefulWidget {
  final ValueNotifier<bool> refreshNotifier;

  const CompanyDetailsScreen({Key? key, required this.refreshNotifier}) : super(key: key);

  @override
  _CompanyDetailsScreenState createState() => _CompanyDetailsScreenState();
}

class _CompanyDetailsScreenState extends State<CompanyDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerName1Controller = TextEditingController();
  final _ownerName2Controller = TextEditingController();
  final _otherNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vatNoController = TextEditingController();
  final _crNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _emailController = TextEditingController();
  
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanyDetails();
  }

  @override
  void dispose() {
    _ownerName1Controller.dispose();
    _ownerName2Controller.dispose();
    _otherNameController.dispose();
    _phoneController.dispose();
    _vatNoController.dispose();
    _crNumberController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyDetails() async {
    try {
      final company = await _dbHelper.getCompany();
      setState(() {
        _ownerName1Controller.text = company.ownerName1;
        _ownerName2Controller.text = company.ownerName2;
        _otherNameController.text = company.otherName;
        _phoneController.text = company.phone;
        _vatNoController.text = company.vatNo;
        _crNumberController.text = company.crNumber;
        _addressController.text = company.address;
        _cityController.text = company.city;
        _emailController.text = company.email;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading company details: $e')),
      );
    }
  }

  Future<void> _saveCompanyDetails() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final company = CompanyDetails(
        id: 1,
        ownerName1: _ownerName1Controller.text,
        ownerName2: _ownerName2Controller.text,
        otherName: _otherNameController.text,
        phone: _phoneController.text,
        vatNo: _vatNoController.text,
        crNumber: _crNumberController.text,
        address: _addressController.text,
        city: _cityController.text,
        email: _emailController.text,
      );

      await _dbHelper.updateCompany(company);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Company details saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      widget.refreshNotifier.value = !widget.refreshNotifier.value;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving company details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Company Details / تفاصيل الشركة'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveCompanyDetails,
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
                              'Company Information / معلومات الشركة',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 20),
                            TextFormField(
                              controller: _ownerName1Controller,
                              decoration: InputDecoration(
                                labelText: 'Owner Name 1 / اسم المالك الأول *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Please enter owner name';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _ownerName2Controller,
                              decoration: InputDecoration(
                                labelText: 'Owner Name 2 / اسم المالك الثاني',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _otherNameController,
                              decoration: InputDecoration(
                                labelText: 'Other Name / اسم آخر',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.business),
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
                              controller: _vatNoController,
                              decoration: InputDecoration(
                                labelText: 'VAT Number / الرقم الضريبي *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.numbers),
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Please enter VAT number';
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
                              maxLines: 2,
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
                                onPressed: _saveCompanyDetails,
                                icon: Icon(Icons.save),
                                label: Text('Save Company Details / حفظ تفاصيل الشركة'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
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