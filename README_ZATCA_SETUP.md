# ZATCA E-Invoicing Integration Setup Guide

This guide will help you set up your Flutter invoice app with Supabase backend and ZATCA e-invoicing system integration.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Supabase Setup](#supabase-setup)
3. [ZATCA API Setup](#zatca-api-setup)
4. [Flutter App Configuration](#flutter-app-configuration)
5. [Database Schema](#database-schema)
6. [Edge Function Deployment](#edge-function-deployment)
7. [Testing](#testing)
8. [Production Deployment](#production-deployment)
9. [Troubleshooting](#troubleshooting)

## Prerequisites

- Flutter SDK (2.17.0 or higher)
- Supabase account
- ZATCA developer account
- Digital certificate for ZATCA signing
- Node.js (for Edge Function development)

## Supabase Setup

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Create a new project
3. Note down your project URL and anon key

### 2. Configure Environment Variables

In your Supabase project dashboard, go to Settings > Environment Variables and add:

```bash
# ZATCA Configuration
ZATCA_BASE_URL=https://gw-fatoora.zatca.gov.sa/e-invoicing/developer-portal
ZATCA_API_TOKEN=your_zatca_api_token
ZATCA_ENVIRONMENT=sandbox

# Digital Certificate
ZATCA_PRIVATE_KEY=your_private_key_content
ZATCA_CERTIFICATE=your_certificate_content
ZATCA_CERT_PASSWORD=your_certificate_password

# Security
JWT_SECRET=your_jwt_secret
ENCRYPTION_KEY=your_32_character_encryption_key
```

### 3. Deploy Database Schema

1. Go to SQL Editor in your Supabase dashboard
2. Copy and paste the contents of `supabase/schema.sql`
3. Execute the SQL to create all tables and policies

### 4. Deploy Edge Function

1. Install Supabase CLI:
```bash
npm install -g supabase
```

2. Login to Supabase:
```bash
supabase login
```

3. Link your project:
```bash
supabase link --project-ref your-project-ref
```

4. Deploy the Edge Function:
```bash
supabase functions deploy zatca-invoice-processor
```

## ZATCA API Setup

### 1. Register for ZATCA Developer Account

1. Visit [ZATCA Developer Portal](https://zatca.gov.sa/en/e-invoicing-systems/developer-portal)
2. Register for a developer account
3. Complete the verification process

### 2. Generate Digital Certificate

1. Follow ZATCA's certificate generation guide
2. Download your private key and certificate
3. Note down the certificate password

### 3. Get API Credentials

1. Log into ZATCA Developer Portal
2. Generate API token for sandbox environment
3. Note down the token and base URL

### 4. Test Sandbox Environment

1. Use ZATCA's sandbox testing tools
2. Verify your certificate works
3. Test basic API calls

## Flutter App Configuration

### 1. Update pubspec.yaml

The dependencies have been updated. Run:
```bash
flutter pub get
```

### 2. Configure Supabase Client

Update `lib/services/supabase_service.dart`:

```dart
Future<void> initialize() async {
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL', // Replace with your URL
    anonKey: 'YOUR_SUPABASE_ANON_KEY', // Replace with your key
  );
  _supabase = Supabase.instance.client;
}
```

### 3. Test Authentication

1. Run the app
2. Create a test account
3. Verify login/logout works

## Database Schema

The following tables are created:

### invoices
- Stores all invoice data
- Tracks sync status
- Stores ZATCA responses

### sync_tracking
- Detailed sync status tracking
- Retry count and error messages
- Timestamps for audit

### sync_logs
- Audit trail for all sync operations
- Error tracking
- Performance monitoring

### company_profiles
- Company information for ZATCA
- VAT registration details
- Contact information

### zatca_certificates
- Digital certificates storage
- Certificate management
- Expiration tracking

### zatca_settings
- ZATCA API configuration
- Environment settings
- Sync preferences

## Edge Function Deployment

### 1. Function Structure

The Edge Function (`zatca-invoice-processor`) handles:

- Invoice validation
- XML generation
- Digital signing
- ZATCA API calls
- Response processing

### 2. Environment Variables

Set these in Supabase dashboard:

```bash
ZATCA_BASE_URL=https://gw-fatoora.zatca.gov.sa/e-invoicing/developer-portal
ZATCA_API_TOKEN=your_token
ZATCA_PRIVATE_KEY=your_private_key
ZATCA_CERTIFICATE=your_certificate
ZATCA_CERT_PASSWORD=your_password
```

### 3. Deploy Function

```bash
supabase functions deploy zatca-invoice-processor --project-ref your-project-ref
```

## Testing

### 1. Test Invoice Creation

1. Create a new invoice in the app
2. Verify it's saved locally
3. Check sync status shows "pending"

### 2. Test Sync Process

1. Press "Sync All" button
2. Monitor sync progress
3. Verify ZATCA response

### 3. Test Error Handling

1. Disconnect internet
2. Try to sync
3. Verify error handling

### 4. Test Retry Logic

1. Force a sync failure
2. Press "Retry Failed"
3. Verify retry works

## Production Deployment

### 1. Update Environment

1. Change ZATCA environment to production
2. Update API URLs
3. Use production certificates

### 2. Security Review

1. Verify all secrets are secure
2. Check RLS policies
3. Review API permissions

### 3. Performance Optimization

1. Monitor sync performance
2. Optimize database queries
3. Set up monitoring

## Troubleshooting

### Common Issues

#### 1. Authentication Errors
- Check Supabase URL and keys
- Verify user registration
- Check RLS policies

#### 2. Sync Failures
- Check internet connectivity
- Verify ZATCA API credentials
- Check certificate validity

#### 3. ZATCA API Errors
- Verify API token
- Check invoice format
- Validate certificate

#### 4. Database Errors
- Check table permissions
- Verify foreign key constraints
- Review RLS policies

### Debug Steps

1. Check Supabase logs
2. Monitor Edge Function logs
3. Review sync logs in app
4. Test API calls manually

### Support

For issues:
1. Check Supabase documentation
2. Review ZATCA API docs
3. Check Flutter logs
4. Contact support if needed

## Security Best Practices

### 1. Certificate Management
- Store certificates securely
- Rotate certificates regularly
- Use environment variables

### 2. API Security
- Use HTTPS only
- Validate all inputs
- Implement rate limiting

### 3. Data Protection
- Encrypt sensitive data
- Use RLS policies
- Audit access logs

## Performance Optimization

### 1. Sync Optimization
- Batch sync operations
- Implement retry logic
- Use background sync

### 2. Database Optimization
- Create proper indexes
- Optimize queries
- Monitor performance

### 3. API Optimization
- Cache responses
- Implement pagination
- Use compression

## Monitoring and Logging

### 1. Set up Monitoring
- Monitor sync success rates
- Track API response times
- Alert on failures

### 2. Logging Strategy
- Log all sync operations
- Track error patterns
- Monitor user activity

### 3. Analytics
- Track invoice volumes
- Monitor sync patterns
- Analyze performance

## Backup and Recovery

### 1. Database Backup
- Set up automated backups
- Test restore procedures
- Monitor backup health

### 2. Certificate Backup
- Backup certificates securely
- Document recovery procedures
- Test certificate rotation

### 3. Disaster Recovery
- Document recovery procedures
- Test recovery scenarios
- Maintain recovery documentation

---

## Quick Start Checklist

- [ ] Create Supabase project
- [ ] Configure environment variables
- [ ] Deploy database schema
- [ ] Deploy Edge Function
- [ ] Set up ZATCA account
- [ ] Configure certificates
- [ ] Update Flutter app
- [ ] Test authentication
- [ ] Test invoice creation
- [ ] Test sync process
- [ ] Test error handling
- [ ] Deploy to production

## Next Steps

1. Implement webhook handling
2. Add advanced reporting
3. Implement batch processing
4. Add user management
5. Implement audit trails
6. Add performance monitoring
7. Implement backup strategies
8. Add compliance reporting

---

For additional support or questions, please refer to the official documentation or contact the development team. 