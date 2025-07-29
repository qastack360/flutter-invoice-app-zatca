import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

class SyncSettingsScreen extends StatefulWidget {
  final ValueNotifier<bool> refreshNotifier;

  const SyncSettingsScreen({Key? key, required this.refreshNotifier}) : super(key: key);

  @override
  _SyncSettingsScreenState createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  bool _autoSyncEnabled = false;
  int _syncIntervalMinutes = 30;
  bool _enableOfflineMode = true;
  bool _isLoading = true;
  
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadSyncSettings();
  }

  Future<void> _loadSyncSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _autoSyncEnabled = prefs.getBool('autoSyncEnabled') ?? false;
        _syncIntervalMinutes = prefs.getInt('syncIntervalMinutes') ?? 30;
        _enableOfflineMode = prefs.getBool('enableOfflineMode') ?? true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading sync settings: $e')),
      );
    }
  }

  Future<void> _saveSyncSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('autoSyncEnabled', _autoSyncEnabled);
      await prefs.setInt('syncIntervalMinutes', _syncIntervalMinutes);
      await prefs.setBool('enableOfflineMode', _enableOfflineMode);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      widget.refreshNotifier.value = !widget.refreshNotifier.value;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving sync settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearSyncData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Sync Data'),
        content: Text('This will clear all sync history. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Clear'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Clear sync logs from Supabase
        await _supabaseService.client
            .from('sync_logs')
            .delete()
            .lt('timestamp', DateTime.now().subtract(Duration(days: 1)).toIso8601String());
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync data cleared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing sync data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sync Settings / إعدادات المزامنة'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveSyncSettings,
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
                            'Synchronization Options / خيارات المزامنة',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 20),
                          SwitchListTile(
                            title: Text('Auto Sync / المزامنة التلقائية'),
                            subtitle: Text('Automatically sync invoices with ZATCA'),
                            value: _autoSyncEnabled,
                            onChanged: (value) {
                              setState(() {
                                _autoSyncEnabled = value;
                              });
                            },
                          ),
                          if (_autoSyncEnabled) ...[
                            ListTile(
                              title: Text('Sync Interval / فاصل المزامنة'),
                              subtitle: Text('${_syncIntervalMinutes} minutes'),
                              trailing: DropdownButton<int>(
                                value: _syncIntervalMinutes,
                                items: [15, 30, 60, 120].map((minutes) {
                                  return DropdownMenuItem(
                                    value: minutes,
                                    child: Text('$minutes min'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _syncIntervalMinutes = value ?? 30;
                                  });
                                },
                              ),
                            ),
                          ],
                          SwitchListTile(
                            title: Text('Offline Mode / الوضع غير المتصل'),
                            subtitle: Text('Allow app to work without internet'),
                            value: _enableOfflineMode,
                            onChanged: (value) {
                              setState(() {
                                _enableOfflineMode = value;
                              });
                            },
                          ),
                          SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saveSyncSettings,
                              icon: Icon(Icons.save),
                              label: Text('Save Sync Settings / حفظ إعدادات المزامنة'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
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
                            'Sync Management / إدارة المزامنة',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _clearSyncData,
                              icon: Icon(Icons.clear_all),
                              label: Text('Clear Sync Data / مسح بيانات المزامنة'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
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
                            'Information / معلومات',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          ListTile(
                            leading: Icon(Icons.info, color: Colors.blue),
                            title: Text('Auto Sync'),
                            subtitle: Text('Automatically syncs invoices with ZATCA at specified intervals.'),
                          ),
                          ListTile(
                            leading: Icon(Icons.info, color: Colors.blue),
                            title: Text('Offline Mode'),
                            subtitle: Text('Allows you to create invoices without internet connection.'),
                          ),
                          ListTile(
                            leading: Icon(Icons.info, color: Colors.blue),
                            title: Text('Sync Data'),
                            subtitle: Text('Clears sync history to free up storage space.'),
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