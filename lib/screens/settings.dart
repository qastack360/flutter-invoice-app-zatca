import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../models/company_details.dart';
import '../models/invoice_settings.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';
import '../config/app_config.dart';
import 'company_details_screen.dart';
import 'invoice_settings_screen.dart';
import 'zatca_settings_screen.dart';
import 'sync_settings_screen.dart';
import 'app_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ValueNotifier<bool> refreshNotifier;

  const SettingsScreen({Key? key, required this.refreshNotifier}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _mockPrinting = false;
  String _userEmail = '';
  String _userName = '';
  
  final SupabaseService _supabaseService = SupabaseService();
  final SyncService _syncService = SyncService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadMockPrintingSetting();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = _supabaseService.currentUser;
      if (user != null) {
        setState(() {
          _userEmail = user.email ?? '';
          _userName = user.userMetadata?['full_name'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  Future<void> _loadMockPrintingSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mockPrinting = prefs.getBool('mockPrinting') ?? false;
    });
  }

  Future<void> _setMockPrinting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mockPrinting', value);
    setState(() {
      _mockPrinting = value;
    });
    widget.refreshNotifier.value = !widget.refreshNotifier.value;
  }

  Future<void> _signOut() async {
    try {
      await _supabaseService.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings / الإعدادات'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Card
            _buildUserInfoCard(),
            SizedBox(height: 16),

            // Settings Categories
            _buildSettingsCategories(),
            SizedBox(height: 16),

            // Mock Printing Toggle (Only on main settings)
            _buildMockPrintingCard(),
            SizedBox(height: 16),

            // About Section
            _buildAboutCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text(
              'User Information / معلومات المستخدم',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            if (_userName.isNotEmpty)
              ListTile(
                leading: Icon(Icons.person),
                title: Text('Name / الاسم'),
                subtitle: Text(_userName),
              ),
          ListTile(
              leading: Icon(Icons.email),
              title: Text('Email / البريد الإلكتروني'),
              subtitle: Text(_userEmail),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _signOut,
                icon: Icon(Icons.logout),
                label: Text('Sign Out / تسجيل الخروج'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCategories() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings Categories / فئات الإعدادات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildCategoryTile(
              icon: Icons.business,
              title: 'Company Details / تفاصيل الشركة',
              subtitle: 'Manage company information',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CompanyDetailsScreen(refreshNotifier: widget.refreshNotifier),
                ),
              ),
            ),
            _buildCategoryTile(
              icon: Icons.receipt_long,
              title: 'Invoice Settings / إعدادات الفاتورة',
              subtitle: 'Configure invoice preferences',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoiceSettingsScreen(refreshNotifier: widget.refreshNotifier),
              ),
            ),
          ),
            _buildCategoryTile(
              icon: Icons.qr_code,
              title: 'ZATCA Settings / إعدادات ضريبة القيمة المضافة',
              subtitle: 'ZATCA e-invoicing configuration',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ZatcaSettingsScreen(refreshNotifier: widget.refreshNotifier),
                ),
              ),
                ),
            _buildCategoryTile(
              icon: Icons.sync,
              title: 'Sync Settings / إعدادات المزامنة',
              subtitle: 'Configure synchronization options',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SyncSettingsScreen(refreshNotifier: widget.refreshNotifier),
              ),
            ),
          ),
            _buildCategoryTile(
              icon: Icons.settings,
              title: 'App Settings / إعدادات التطبيق',
              subtitle: 'General application preferences',
            onTap: () => Navigator.push(
              context,
                MaterialPageRoute(
                  builder: (_) => AppSettingsScreen(refreshNotifier: widget.refreshNotifier),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue[100],
        child: Icon(icon, color: Colors.blue[700]),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildMockPrintingCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Printing Options / خيارات الطباعة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
            SizedBox(height: 16),
          SwitchListTile(
              title: Text('Mock Printing / الطباعة الوهمية'),
              subtitle: Text('Use mock printing for testing'),
            value: _mockPrinting,
              onChanged: _setMockPrinting,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About / حول',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.info),
              title: Text('App Version / إصدار التطبيق'),
              subtitle: Text(AppConfig.appVersion),
            ),
            ListTile(
              leading: Icon(Icons.description),
              title: Text('Description / الوصف'),
              subtitle: Text('Flutter Invoice App with ZATCA Integration'),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  showAboutDialog(
                    context: context,
                    applicationName: AppConfig.appName,
                    applicationVersion: AppConfig.appVersion,
                    applicationIcon: Image.asset(
                      AppConfig.logoPath,
                      width: 50,
                      height: 50,
                    ),
                    children: [
                      Text('Flutter Invoice App with ZATCA Integration'),
                      SizedBox(height: 8),
                      Text('Supports Saudi Arabia e-invoicing system'),
                    ],
                  );
            },
                icon: Icon(Icons.info),
                label: Text('More Info / المزيد من المعلومات'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
          ),
        ],
        ),
      ),
    );
  }
}