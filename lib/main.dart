import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/create_invoice.dart';
import 'screens/history.dart';
import 'screens/settings.dart';
import 'screens/zatca_history_screen.dart';
import 'screens/local_history_screen.dart';
import 'screens/company_details_screen.dart';
import 'screens/invoice_settings_screen.dart';
import 'screens/zatca_settings_screen.dart';
import 'screens/sync_settings_screen.dart';
import 'screens/app_settings_screen.dart';
import 'services/supabase_service.dart';

// ✅ Add this line at the top
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseService().initialize();

  // Load Arabic fonts
  final arabicFontLoader = FontLoader('NotoNaskhArabic')
    ..addFont(rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoNaskhArabic-Bold.ttf'));

  await arabicFontLoader.load();

  runApp(InvoiceApp());
}

class InvoiceApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Invoice App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      navigatorKey: navigatorKey, // ✅ Required for Overlay capture
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Listen to auth state changes
    _supabaseService.client.auth.onAuthStateChange.listen((data) {
      setState(() {
        _isLoading = false;
      });
    });

    // Check initial auth state
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    // Check if user is authenticated
    if (_supabaseService.isAuthenticated) {
      return HomeScreen();
    } else {
      return LoginScreen();
    }
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabaseService = SupabaseService();
  bool _isLoading = false;
  bool _isSignUp = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login / تسجيل الدخول'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 80,
              color: Colors.green,
            ),
            SizedBox(height: 32),
            Text(
              'Invoice App with ZATCA',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email / البريد الإلكتروني',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password / كلمة المرور',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleAuth,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(_isSignUp ? 'Sign Up / تسجيل' : 'Login / دخول'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _isSignUp = !_isSignUp;
                });
              },
              child: Text(
                _isSignUp
                    ? 'Already have an account? Login'
                    : 'Don\'t have an account? Sign Up',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isSignUp) {
        await _supabaseService.signUpWithEmail(
          _emailController.text,
          _passwordController.text,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account created successfully! Please check your email.')),
        );
      } else {
        await _supabaseService.signInWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final _refreshHistoryNotifier = ValueNotifier<bool>(false);
  final _refreshCreateNotifier = ValueNotifier<bool>(false);
  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _screens.addAll([
      CreateInvoiceScreen(refreshNotifier: _refreshCreateNotifier),
      HistoryScreen(refreshNotifier: _refreshHistoryNotifier),
      SettingsScreen(refreshNotifier: _refreshCreateNotifier),
    ]);
  }

  final List<Color> _topColors = [Colors.green, Colors.yellow, Colors.blue];

  void _showHistoryOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select History Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.qr_code, color: Colors.orange),
              title: Text('ZATCA History'),
              subtitle: Text('Invoices sent to ZATCA system'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ZatcaHistoryScreen(refreshNotifier: _refreshHistoryNotifier),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.storage, color: Colors.blue),
              title: Text('Local History'),
              subtitle: Text('Offline invoices'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocalHistoryScreen(refreshNotifier: _refreshHistoryNotifier),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice App'),
        backgroundColor: _topColors[_selectedIndex],
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await SupabaseService().signOut();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      floatingActionButton: _selectedIndex == 1 ? FloatingActionButton.extended(
        onPressed: () {
          _showHistoryOptions();
        },
        icon: Icon(Icons.history),
        label: Text('History Options'),
        backgroundColor: Colors.orange,
      ) : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) {
            _refreshHistoryNotifier.value = !_refreshHistoryNotifier.value;
          } else if (index == 0) {
            _refreshCreateNotifier.value = !_refreshCreateNotifier.value;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Create'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
