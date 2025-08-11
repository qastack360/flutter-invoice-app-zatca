-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create invoices table
CREATE TABLE IF NOT EXISTS invoices (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    invoice_number INTEGER NOT NULL,
    invoice_prefix TEXT,
    invoice_date TIMESTAMP WITH TIME ZONE NOT NULL,
    customer_name TEXT NOT NULL,
    salesman TEXT,
    vat_number TEXT,
    total_amount DECIMAL(10,2) NOT NULL,
    vat_amount DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2),
    discount DECIMAL(10,2) DEFAULT 0,
    cash DECIMAL(10,2) DEFAULT 0,
    vat_percent DECIMAL(5,2) DEFAULT 15.0,
    items JSONB NOT NULL,
    company_details JSONB NOT NULL,
    zatca_invoice BOOLEAN DEFAULT false,
    zatca_uuid TEXT,
    zatca_environment TEXT DEFAULT 'sandbox',
    zatca_response JSONB,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'in_progress', 'completed', 'failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create sync_tracking table for detailed sync status
CREATE TABLE IF NOT EXISTS sync_tracking (
    id BIGSERIAL PRIMARY KEY,
    invoice_id TEXT UNIQUE NOT NULL,
    invoice_number INTEGER NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'in_progress', 'completed', 'failed')),
    zatca_uuid TEXT,
    zatca_qr_code TEXT,
    zatca_response JSONB,
    sync_timestamp TIMESTAMP WITH TIME ZONE,
    retry_count INTEGER DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Create sync_logs table for audit trail
CREATE TABLE IF NOT EXISTS sync_logs (
    id BIGSERIAL PRIMARY KEY,
    action TEXT NOT NULL,
    status TEXT NOT NULL,
    details TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    invoice_id TEXT,
    request_id TEXT
);

-- Create company_profiles table
CREATE TABLE IF NOT EXISTS company_profiles (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    company_name TEXT NOT NULL,
    vat_number TEXT NOT NULL,
    cr_number TEXT,
    address TEXT,
    city TEXT,
    postal_code TEXT,
    country TEXT DEFAULT 'SA',
    phone TEXT,
    email TEXT,
    logo_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create zatca_certificates table for storing certificates
CREATE TABLE IF NOT EXISTS zatca_certificates (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    certificate_name TEXT NOT NULL,
    certificate_data TEXT NOT NULL,
    private_key TEXT NOT NULL,
    certificate_password TEXT,
    is_active BOOLEAN DEFAULT true,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create zatca_settings table
CREATE TABLE IF NOT EXISTS zatca_settings (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    environment TEXT DEFAULT 'sandbox' CHECK (environment IN ('sandbox', 'production')),
    api_token TEXT,
    base_url TEXT,
    auto_sync BOOLEAN DEFAULT false,
    sync_interval_minutes INTEGER DEFAULT 30,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_invoices_user_id ON invoices(user_id);
CREATE INDEX IF NOT EXISTS idx_invoices_sync_status ON invoices(sync_status);
CREATE INDEX IF NOT EXISTS idx_invoices_created_at ON invoices(created_at);
CREATE INDEX IF NOT EXISTS idx_invoices_invoice_number ON invoices(invoice_number);

CREATE INDEX IF NOT EXISTS idx_sync_tracking_user_id ON sync_tracking(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_tracking_sync_status ON sync_tracking(sync_status);
CREATE INDEX IF NOT EXISTS idx_sync_tracking_invoice_id ON sync_tracking(invoice_id);

CREATE INDEX IF NOT EXISTS idx_sync_logs_user_id ON sync_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_logs_timestamp ON sync_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_sync_logs_action ON sync_logs(action);

CREATE INDEX IF NOT EXISTS idx_company_profiles_user_id ON company_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_company_profiles_vat_number ON company_profiles(vat_number);

CREATE INDEX IF NOT EXISTS idx_zatca_certificates_user_id ON zatca_certificates(user_id);
CREATE INDEX IF NOT EXISTS idx_zatca_certificates_is_active ON zatca_certificates(is_active);

-- Create functions for automatic timestamp updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for automatic timestamp updates
CREATE TRIGGER update_invoices_updated_at BEFORE UPDATE ON invoices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sync_tracking_updated_at BEFORE UPDATE ON sync_tracking
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_company_profiles_updated_at BEFORE UPDATE ON company_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_zatca_certificates_updated_at BEFORE UPDATE ON zatca_certificates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_zatca_settings_updated_at BEFORE UPDATE ON zatca_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create RLS (Row Level Security) policies
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE zatca_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE zatca_settings ENABLE ROW LEVEL SECURITY;

-- Policies for invoices table
CREATE POLICY "Users can view their own invoices" ON invoices
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own invoices" ON invoices
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own invoices" ON invoices
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own invoices" ON invoices
    FOR DELETE USING (auth.uid() = user_id);

-- Policies for sync_tracking table
CREATE POLICY "Users can view their own sync tracking" ON sync_tracking
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own sync tracking" ON sync_tracking
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own sync tracking" ON sync_tracking
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own sync tracking" ON sync_tracking
    FOR DELETE USING (auth.uid() = user_id);

-- Policies for sync_logs table
CREATE POLICY "Users can view their own sync logs" ON sync_logs
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own sync logs" ON sync_logs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policies for company_profiles table
CREATE POLICY "Users can view their own company profile" ON company_profiles
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own company profile" ON company_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own company profile" ON company_profiles
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own company profile" ON company_profiles
    FOR DELETE USING (auth.uid() = user_id);

-- Policies for zatca_certificates table
CREATE POLICY "Users can view their own certificates" ON zatca_certificates
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own certificates" ON zatca_certificates
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own certificates" ON zatca_certificates
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own certificates" ON zatca_certificates
    FOR DELETE USING (auth.uid() = user_id);

-- Policies for zatca_settings table
CREATE POLICY "Users can view their own settings" ON zatca_settings
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own settings" ON zatca_settings
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own settings" ON zatca_settings
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own settings" ON zatca_settings
    FOR DELETE USING (auth.uid() = user_id);

-- Create views for easier data access
CREATE OR REPLACE VIEW invoice_summary AS
SELECT 
    i.id,
    i.invoice_number,
    i.invoice_date,
    i.customer_name,
    i.total_amount,
    i.vat_amount,
    i.sync_status,
    i.zatca_uuid,
    i.created_at,
    u.email as user_email
FROM invoices i
JOIN auth.users u ON i.user_id = u.id;

CREATE OR REPLACE VIEW sync_status_summary AS
SELECT 
    sync_status,
    COUNT(*) as count,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage
FROM invoices
GROUP BY sync_status;

-- Create function to get sync statistics
CREATE OR REPLACE FUNCTION get_sync_stats(user_uuid UUID)
RETURNS TABLE(
    total_count BIGINT,
    pending_count BIGINT,
    completed_count BIGINT,
    failed_count BIGINT,
    in_progress_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_count,
        COUNT(*) FILTER (WHERE sync_status = 'pending') as pending_count,
        COUNT(*) FILTER (WHERE sync_status = 'completed') as completed_count,
        COUNT(*) FILTER (WHERE sync_status = 'failed') as failed_count,
        COUNT(*) FILTER (WHERE sync_status = 'in_progress') as in_progress_count
    FROM invoices
    WHERE user_id = user_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to clean old sync logs
CREATE OR REPLACE FUNCTION clean_old_sync_logs(days_old INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM sync_logs 
    WHERE timestamp < NOW() - INTERVAL '1 day' * days_old;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 