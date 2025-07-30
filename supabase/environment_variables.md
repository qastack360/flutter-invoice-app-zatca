# ZATCA Environment Variables for Supabase

## 🔧 **Complete Environment Variables Setup**

Copy and paste these environment variables into your Supabase project:

### **1. Go to Supabase Dashboard:**
1. Open your Supabase project
2. Go to **Settings** → **Environment Variables**
3. Add each variable below

### **2. ZATCA API Configuration:**

```bash
# ZATCA Base Configuration
ZATCA_BASE_URL=https://gw-fatoora.zatca.gov.sa/e-invoicing/developer-portal
ZATCA_ENVIRONMENT=sandbox

# ZATCA Authentication
ZATCA_USERNAME=flutterinvoiceapp@gmail.com
ZATCA_PASSWORD=your_zatca_password_here
ZATCA_AUTHORIZATION=Basic Zmx1dHRlcmludm9pY2VhcHBAZ21haWwuY29t0lJpendhbiMxMTIy

# ZATCA API Endpoints
ZATCA_COMPLIANCE_ENDPOINT=/compliance/invoices
ZATCA_REPORTING_ENDPOINT=/invoices/reporting/single
ZATCA_CLEARANCE_ENDPOINT=/invoices/clearance/single

# ZATCA Headers
ZATCA_ACCEPT_VERSION=V2
ZATCA_ACCEPT_LANGUAGE=en
ZATCA_CLEARANCE_STATUS=1

# Digital Certificate (if you have one)
ZATCA_PRIVATE_KEY=your_private_key_content_here
ZATCA_CERTIFICATE=your_certificate_content_here
ZATCA_CERT_PASSWORD=your_certificate_password_here

# Security
JWT_SECRET=your_jwt_secret_here
ENCRYPTION_KEY=your_32_character_encryption_key_here

# Webhook (for production)
ZATCA_WEBHOOK_SECRET=your_webhook_secret_here
```

### **3. Required Variables (Must Set):**

```bash
# These are the minimum required variables
ZATCA_BASE_URL=https://gw-fatoora.zatca.gov.sa/e-invoicing/developer-portal
ZATCA_USERNAME=flutterinvoiceapp@gmail.com
ZATCA_PASSWORD=your_actual_zatca_password
ZATCA_AUTHORIZATION=Basic Zmx1dHRlcmludm9pY2VhcHBAZ21haWwuY29t0lJpendhbiMxMTIy
JWT_SECRET=your_random_jwt_secret
ENCRYPTION_KEY=your_32_character_random_key
```

### **4. Optional Variables (Set if you have certificates):**

```bash
# Only set these if you have digital certificates
ZATCA_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\nYour private key content\n-----END PRIVATE KEY-----
ZATCA_CERTIFICATE=-----BEGIN CERTIFICATE-----\nYour certificate content\n-----END CERTIFICATE-----
ZATCA_CERT_PASSWORD=your_certificate_password
```

### **5. How to Set Environment Variables:**

1. **In Supabase Dashboard:**
   - Go to **Settings** → **Environment Variables**
   - Click **"Add new variable"**
   - Enter **Name** and **Value**
   - Click **"Save"**

2. **Example:**
   - **Name:** `ZATCA_BASE_URL`
   - **Value:** `https://gw-fatoora.zatca.gov.sa/e-invoicing/developer-portal`

### **6. Security Notes:**

- ✅ **Never commit these to Git**
- ✅ **Use strong, random values for secrets**
- ✅ **Keep your ZATCA password secure**
- ✅ **Rotate secrets regularly**

### **7. Testing Your Configuration:**

After setting the variables, test with:

```bash
# Deploy the Edge Function
supabase functions deploy zatca-invoice-processor

# Test the function
curl -X POST https://your-project.supabase.co/functions/v1/zatca-invoice-processor \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

### **8. Production vs Sandbox:**

For **Production**, change:
```bash
ZATCA_ENVIRONMENT=production
ZATCA_BASE_URL=https://gw-fatoora.zatca.gov.sa/e-invoicing
```

For **Sandbox** (current):
```bash
ZATCA_ENVIRONMENT=sandbox
ZATCA_BASE_URL=https://gw-fatoora.zatca.gov.sa/e-invoicing/developer-portal
```

## 🎯 **Next Steps:**

1. **Set all environment variables** in Supabase
2. **Deploy the Edge Function**
3. **Test the ZATCA integration**
4. **Update your Flutter app configuration**

## 📞 **Need Help?**

If you encounter issues:
1. Check Supabase logs
2. Verify environment variables are set correctly
3. Test API endpoints manually
4. Contact support if needed 