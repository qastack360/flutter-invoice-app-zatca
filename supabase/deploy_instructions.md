# ZATCA Integration Deployment Guide

## 🚀 **Deployment Steps**

### **1. Set Environment Variables in Supabase:**

Go to your Supabase Dashboard → Settings → Environment Variables and add:

```bash
# Required Variables
ZATCA_BASE_URL=https://gw-fatoora.zatca.gov.sa/e-invoicing/developer-portal
ZATCA_USERNAME=flutterinvoiceapp@gmail.com
ZATCA_PASSWORD=your_zatca_password_here
ZATCA_AUTHORIZATION=Basic Zmx1dHRlcmludm9pY2VhcHBAZ21haWwuY29t0lJpendhbiMxMTIy
JWT_SECRET=your_random_jwt_secret_here
ENCRYPTION_KEY=your_32_character_random_key_here

# Optional (if you have certificates)
ZATCA_PRIVATE_KEY=your_private_key_content
ZATCA_CERTIFICATE=your_certificate_content
ZATCA_CERT_PASSWORD=your_certificate_password
```

### **2. Deploy Edge Functions:**

```bash
# Deploy ZATCA Invoice Processor
supabase functions deploy zatca-invoice-processor

# Deploy ZATCA Webhook Handler
supabase functions deploy zatca-webhook
```

### **3. Update Flutter App Configuration:**

Update `lib/services/supabase_service.dart` with your Supabase URL and key:

```dart
Future<void> initialize() async {
  await Supabase.initialize(
    url: 'https://your-project-ref.supabase.co',
    anonKey: 'your-anon-key-here',
  );
  _supabase = Supabase.instance.client;
}
```

### **4. Test the Integration:**

1. **Create a test invoice** in your Flutter app
2. **Enable "Send to ZATCA"** toggle
3. **Press "Sync"** button
4. **Check the response** in Supabase logs

## ✅ **What's Been Updated:**

### **ZATCA APIs Configured:**
- ✅ **Compliance API**: `/compliance/invoices`
- ✅ **Reporting API**: `/invoices/reporting/single`
- ✅ **Clearance API**: `/invoices/clearance/single`

### **Authentication:**
- ✅ **Basic Auth** with your ZATCA credentials
- ✅ **Correct headers** for each API
- ✅ **Proper request format** (JSON with Base64 XML)

### **Process Flow:**
1. **Compliance** → Validates invoice format
2. **Reporting** → Submits to ZATCA
3. **Clearance** → Gets QR code and approval

## 🎯 **Ready to Deploy!**

Your ZATCA integration is now fully configured with all the correct APIs and authentication methods. Follow the deployment steps above to get it running! 