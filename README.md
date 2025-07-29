# 🧾 Flutter Invoice App with ZATCA Integration

A complete, professional Flutter invoice application with Saudi Arabia's ZATCA e-invoicing system integration.

## ✨ Features

### 🏢 **Invoice Management**
- **Dual Invoice System**: ZATCA e-invoices and Local offline invoices
- **Smart Numbering**: Separate sequences (ZATCA-0001, LOCAL-0001)
- **Professional Templates**: Clean, modern invoice design
- **Multi-language Support**: English and Arabic

### ⚙️ **Settings Management**
- **Category-based Organization**: 
  - Company Details
  - Invoice Settings
  - ZATCA Settings
  - Sync Settings
  - App Settings
- **Backend Connected**: All settings sync with Supabase

### 📊 **History & Export**
- **Dual History Screens**: ZATCA and Local separate
- **Environment Filtering**: Sandbox/Live for ZATCA
- **Monthly Export**: CSV and PDF reports
- **Search & Filter**: Easy invoice management

### 🔗 **ZATCA E-invoicing**
- **Saudi Compliance**: Full ZATCA specification compliance
- **Digital Signing**: Certificate-based invoice signing
- **QR Code Generation**: ZATCA verification QR codes
- **API Integration**: Direct ZATCA system integration

### 🖨️ **Printing & Export**
- **Thermal Printing**: Bluetooth printer support
- **Mock Printing**: Testing mode
- **PDF Generation**: Professional PDF invoices
- **CSV Export**: Data analysis ready

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.0+)
- Dart SDK (2.17+)
- Supabase account
- ZATCA developer account (for e-invoicing)

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/YOUR_USERNAME/flutter-invoice-app-zatca.git
cd flutter-invoice-app-zatca
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure Supabase**
```bash
# Link your Supabase project
supabase link --project-ref YOUR_PROJECT_REF

# Deploy database schema
supabase db push

# Deploy Edge Functions
supabase functions deploy zatca-invoice-processor
supabase functions deploy zatca-webhook
```

4. **Set environment variables**
```bash
supabase secrets set ZATCA_SANDBOX_API_URL=your_sandbox_url
supabase secrets set ZATCA_PRODUCTION_API_URL=your_production_url
# ... add other ZATCA credentials
```

5. **Run the app**
```bash
flutter run
```

## 📱 App Structure

### Screens
- **Create Invoice**: Invoice creation with ZATCA toggle
- **History**: Dual history with export options
- **Settings**: Category-based settings management

### Services
- **SupabaseService**: Backend integration
- **SyncService**: Data synchronization
- **PrinterService**: Thermal printing
- **QRService**: QR code generation

### Models
- **Invoice**: Invoice data structure
- **CompanyDetails**: Business information
- **InvoiceSettings**: App configuration

## 🔧 Configuration

### ZATCA Setup
1. Register at [ZATCA Developer Portal](https://zatca.gov.sa/en/e-invoicing/developer-portal)
2. Get sandbox credentials
3. Configure certificates
4. Set environment variables

### Supabase Setup
1. Create Supabase project
2. Deploy schema and functions
3. Configure authentication
4. Set up Row Level Security

## 📋 Usage

### Creating Invoices
1. Open Create Invoice screen
2. Fill customer and item details
3. Toggle "Send to ZATCA" for e-invoicing
4. Click Print to process

### Managing History
1. Use History Options button
2. Choose ZATCA or Local history
3. Filter by environment (ZATCA)
4. Export monthly reports

### Settings Management
1. Navigate to Settings
2. Choose category (Company, Invoice, ZATCA, etc.)
3. Configure settings
4. Save changes

## 🏗️ Architecture

### Frontend (Flutter)
- **State Management**: ValueNotifier for reactive UI
- **Navigation**: Bottom navigation with category screens
- **Storage**: SharedPreferences for local data
- **Printing**: Bluetooth thermal printer integration

### Backend (Supabase)
- **Database**: PostgreSQL with RLS
- **Authentication**: Supabase Auth
- **Edge Functions**: ZATCA processing and webhooks
- **Storage**: File storage for certificates

### ZATCA Integration
- **API Calls**: Compliance, reporting, clearance
- **Digital Signing**: SHA-256 with certificates
- **QR Generation**: ZATCA specification compliance
- **Webhook Handling**: Callback processing

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📞 Support

For support and questions:
- Create an issue on GitHub
- Check the documentation
- Review the deployment guide

## 🎯 Roadmap

- [ ] Advanced reporting features
- [ ] Multi-currency support
- [ ] Offline-first improvements
- [ ] Enhanced ZATCA compliance
- [ ] Mobile app store deployment

---

**Built with ❤️ for Saudi Arabia's e-invoicing compliance**
