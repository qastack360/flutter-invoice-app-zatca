class AppConfig {
  // Supabase Configuration
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  
  // ZATCA Configuration
  static const String zatcaBaseUrl = 'https://gw-fatoora.zatca.gov.sa/e-invoicing/developer-portal';
  static const String zatcaEnvironment = 'sandbox'; // Change to 'production' for live
  
  // App Configuration
  static const String appName = 'Invoice App with ZATCA';
  static const String appVersion = '1.0.0';
  
  // Sync Configuration
  static const int maxRetryAttempts = 3;
  static const int syncTimeoutSeconds = 30;
  static const int autoSyncIntervalMinutes = 30;
  
  // Database Configuration
  static const int databaseVersion = 2;
  static const String databaseName = 'invoice_app.db';
  
  // UI Configuration
  static const double defaultPadding = 16.0;
  static const double cardElevation = 3.0;
  static const double borderRadius = 12.0;
  
  // Colors
  static const int primaryColor = 0xFF4CAF50; // Green
  static const int secondaryColor = 0xFFFFC107; // Yellow
  static const int accentColor = 0xFF2196F3; // Blue
  static const int errorColor = 0xFFF44336; // Red
  static const int successColor = 0xFF4CAF50; // Green
  static const int warningColor = 0xFFFF9800; // Orange
  
  // Font Configuration
  static const String arabicFontFamily = 'NotoNaskhArabic';
  static const String englishFontFamily = 'NotoSans';
  
  // Feature Flags
  static const bool enableAutoSync = true;
  static const bool enableOfflineMode = true;
  static const bool enableZatcaIntegration = true;
  static const bool enableBluetoothPrinting = true;
  static const bool enableMockPrinting = true; // Set to false in production
  
  // Validation Rules
  static const int minPasswordLength = 6;
  static const int maxInvoiceNumber = 999999;
  static const double maxInvoiceAmount = 999999.99;
  static const int maxItemsPerInvoice = 100;
  
  // API Configuration
  static const int apiTimeoutSeconds = 30;
  static const int maxConcurrentRequests = 5;
  static const bool enableApiCaching = true;
  static const int cacheExpiryMinutes = 60;
  
  // Error Messages
  static const Map<String, String> errorMessages = {
    'network_error': 'Network connection error. Please check your internet connection.',
    'auth_error': 'Authentication failed. Please check your credentials.',
    'sync_error': 'Sync failed. Please try again later.',
    'zatca_error': 'ZATCA processing failed. Please contact support.',
    'validation_error': 'Invalid data. Please check your input.',
    'database_error': 'Database error. Please restart the app.',
    'unknown_error': 'An unknown error occurred. Please try again.',
  };
  
  // Success Messages
  static const Map<String, String> successMessages = {
    'login_success': 'Login successful!',
    'logout_success': 'Logout successful!',
    'invoice_created': 'Invoice created successfully!',
    'invoice_synced': 'Invoice synced with ZATCA successfully!',
    'sync_completed': 'All invoices synced successfully!',
    'settings_saved': 'Settings saved successfully!',
  };
  
  // ZATCA Status Messages
  static const Map<String, String> zatcaStatusMessages = {
    'pending': 'Pending sync with ZATCA',
    'in_progress': 'Syncing with ZATCA...',
    'completed': 'Successfully synced with ZATCA',
    'failed': 'Failed to sync with ZATCA',
  };
  
  // Validation Patterns
  static const String emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String vatNumberPattern = r'^[0-9]{15}$';
  static const String phonePattern = r'^[0-9+\-\s()]{10,}$';
  
  // File Paths
  static const String logoPath = 'assets/logo.png';
  static const String qrFallbackPath = 'assets/images/qr_fallback.png';
  
  // Local Storage Keys
  static const String invoicesKey = 'invoices';
  static const String settingsKey = 'settings';
  static const String userPrefsKey = 'user_preferences';
  static const String syncStatsKey = 'sync_stats';
  static const String lastSyncKey = 'last_sync';
  
  // Debug Configuration
  static const bool enableDebugLogging = true;
  static const bool enablePerformanceLogging = false;
  static const bool enableCrashReporting = true;
  
  // Production Configuration
  static bool get isProduction => zatcaEnvironment == 'production';
  static bool get isDevelopment => zatcaEnvironment == 'sandbox';
  
  // Feature Availability
  static bool get canUseZatca => enableZatcaIntegration && isProduction;
  static bool get canUseAutoSync => enableAutoSync && enableZatcaIntegration;
  static bool get canUseBluetoothPrinting => enableBluetoothPrinting && !enableMockPrinting;
  
  // Validation Methods
  static bool isValidEmail(String email) {
    return RegExp(emailPattern).hasMatch(email);
  }
  
  static bool isValidVatNumber(String vatNumber) {
    return RegExp(vatNumberPattern).hasMatch(vatNumber);
  }
  
  static bool isValidPhone(String phone) {
    return RegExp(phonePattern).hasMatch(phone);
  }
  
  static bool isValidPassword(String password) {
    return password.length >= minPasswordLength;
  }
  
  static bool isValidInvoiceNumber(int number) {
    return number > 0 && number <= maxInvoiceNumber;
  }
  
  static bool isValidInvoiceAmount(double amount) {
    return amount > 0 && amount <= maxInvoiceAmount;
  }
  
  // Helper Methods
  static String getErrorMessage(String key) {
    return errorMessages[key] ?? errorMessages['unknown_error']!;
  }
  
  static String getSuccessMessage(String key) {
    return successMessages[key] ?? 'Operation completed successfully!';
  }
  
  static String getZatcaStatusMessage(String status) {
    return zatcaStatusMessages[status] ?? 'Unknown status';
  }
  
  // Environment-specific Configuration
  static Map<String, dynamic> getEnvironmentConfig() {
    if (isProduction) {
      return {
        'zatcaBaseUrl': 'https://gw-fatoora.zatca.gov.sa/e-invoicing',
        'enableMockPrinting': false,
        'enableDebugLogging': false,
        'enableCrashReporting': true,
      };
    } else {
      return {
        'zatcaBaseUrl': 'https://gw-fatoora.zatca.gov.sa/e-invoicing/developer-portal',
        'enableMockPrinting': true,
        'enableDebugLogging': true,
        'enableCrashReporting': false,
      };
    }
  }
} 