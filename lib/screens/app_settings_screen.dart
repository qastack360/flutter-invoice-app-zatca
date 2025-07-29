import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class AppSettingsScreen extends StatefulWidget {
  final ValueNotifier<bool> refreshNotifier;

  const AppSettingsScreen({Key? key, required this.refreshNotifier}) : super(key: key);

  @override
  _AppSettingsScreenState createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _enableDebugLogging = false;
  bool _enableCrashReporting = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppSettings();
  }

  Future<void> _loadAppSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _enableDebugLogging = prefs.getBool('enableDebugLogging') ?? false;
        _enableCrashReporting = prefs.getBool('enableCrashReporting') ?? true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading app settings: $e')),
      );
    }
  }

  Future<void> _saveAppSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('enableDebugLogging', _enableDebugLogging);
      await prefs.setBool('enableCrashReporting', _enableCrashReporting);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('App settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      widget.refreshNotifier.value = !widget.refreshNotifier.value;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving app settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('App Settings / إعدادات التطبيق'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveAppSettings,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
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
                            'General Preferences / التفضيلات العامة',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 20),
                          SwitchListTile(
                            title: Text('Debug Logging / تسجيل الأخطاء'),
                            subtitle: Text('Enable detailed logging for debugging'),
                            value: _enableDebugLogging,
                            onChanged: (value) {
                              setState(() {
                                _enableDebugLogging = value;
                              });
                            },
                          ),
                          SwitchListTile(
                            title: Text('Crash Reporting / تقارير الأعطال'),
                            subtitle: Text('Send crash reports to improve app'),
                            value: _enableCrashReporting,
                            onChanged: (value) {
                              setState(() {
                                _enableCrashReporting = value;
                              });
                            },
                          ),
                          SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saveAppSettings,
                              icon: Icon(Icons.save),
                              label: Text('Save App Settings / حفظ إعدادات التطبيق'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
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
                            'App Information / معلومات التطبيق',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          ListTile(
                            leading: Icon(Icons.info, color: Colors.blue),
                            title: Text('App Name'),
                            subtitle: Text(AppConfig.appName),
                          ),
                          ListTile(
                            leading: Icon(Icons.info, color: Colors.blue),
                            title: Text('Version'),
                            subtitle: Text(AppConfig.appVersion),
                          ),
                          ListTile(
                            leading: Icon(Icons.info, color: Colors.blue),
                            title: Text('Description'),
                            subtitle: Text('Flutter Invoice App with ZATCA Integration'),
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
                            'Information / معلومات',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          ListTile(
                            leading: Icon(Icons.info, color: Colors.blue),
                            title: Text('Debug Logging'),
                            subtitle: Text('Enables detailed logs for troubleshooting issues.'),
                          ),
                          ListTile(
                            leading: Icon(Icons.info, color: Colors.blue),
                            title: Text('Crash Reporting'),
                            subtitle: Text('Helps improve app stability by reporting crashes.'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 