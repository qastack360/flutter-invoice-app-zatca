-- Additional Schema for Complete App Functionality
-- Run this after the main schema.sql

-- 1. Update invoices table with missing fields
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS zatca_invoice BOOLEAN DEFAULT false;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS zatca_environment TEXT DEFAULT 'live';
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS invoice_prefix TEXT DEFAULT 'INV';

-- 2. Create app_settings table
CREATE TABLE IF NOT EXISTS app_settings (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    enable_debug_logging BOOLEAN DEFAULT false,
    enable_crash_reporting BOOLEAN DEFAULT true,
    mock_printing_enabled BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create invoice_numbering table
CREATE TABLE IF NOT EXISTS invoice_numbering (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    zatca_start_invoice INTEGER DEFAULT 1,
    local_start_invoice INTEGER DEFAULT 1,
    zatca_prefix TEXT DEFAULT 'ZATCA',
    local_prefix TEXT DEFAULT 'LOCAL',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Create export_history table
CREATE TABLE IF NOT EXISTS export_history (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    export_type TEXT NOT NULL CHECK (export_type IN ('csv', 'pdf')),
    invoice_type TEXT NOT NULL CHECK (invoice_type IN ('zatca', 'local')),
    environment TEXT,
    month_year TEXT NOT NULL,
    file_path TEXT,
    record_count INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Create indexes for new tables
CREATE INDEX IF NOT EXISTS idx_app_settings_user_id ON app_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_invoice_numbering_user_id ON invoice_numbering(user_id);
CREATE INDEX IF NOT EXISTS idx_export_history_user_id ON export_history(user_id);
CREATE INDEX IF NOT EXISTS idx_export_history_type ON export_history(export_type);
CREATE INDEX IF NOT EXISTS idx_export_history_invoice_type ON export_history(invoice_type);

-- 6. Create triggers for automatic timestamp updates
CREATE TRIGGER update_app_settings_updated_at BEFORE UPDATE ON app_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_invoice_numbering_updated_at BEFORE UPDATE ON invoice_numbering
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 7. Enable RLS for new tables
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_numbering ENABLE ROW LEVEL SECURITY;
ALTER TABLE export_history ENABLE ROW LEVEL SECURITY;

-- 8. Create RLS policies for app_settings
CREATE POLICY "Users can view their own app settings" ON app_settings
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own app settings" ON app_settings
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own app settings" ON app_settings
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own app settings" ON app_settings
    FOR DELETE USING (auth.uid() = user_id);

-- 9. Create RLS policies for invoice_numbering
CREATE POLICY "Users can view their own invoice numbering" ON invoice_numbering
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own invoice numbering" ON invoice_numbering
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own invoice numbering" ON invoice_numbering
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own invoice numbering" ON invoice_numbering
    FOR DELETE USING (auth.uid() = user_id);

-- 10. Create RLS policies for export_history
CREATE POLICY "Users can view their own export history" ON export_history
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own export history" ON export_history
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own export history" ON export_history
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own export history" ON export_history
    FOR DELETE USING (auth.uid() = user_id);

-- 11. Create views for easier data access
CREATE OR REPLACE VIEW invoice_summary_with_type AS
SELECT 
    i.id,
    i.invoice_number,
    i.invoice_prefix,
    i.invoice_date,
    i.customer_name,
    i.total_amount,
    i.vat_amount,
    i.sync_status,
    i.zatca_invoice,
    i.zatca_environment,
    i.zatca_uuid,
    i.created_at,
    u.email as user_email
FROM invoices i
JOIN auth.users u ON i.user_id = u.id;

CREATE OR REPLACE VIEW export_summary AS
SELECT 
    export_type,
    invoice_type,
    environment,
    month_year,
    COUNT(*) as export_count,
    SUM(record_count) as total_records
FROM export_history
GROUP BY export_type, invoice_type, environment, month_year;

-- 12. Create function to get invoice numbering stats
CREATE OR REPLACE FUNCTION get_invoice_numbering_stats(user_uuid UUID)
RETURNS TABLE(
    zatca_current INTEGER,
    local_current INTEGER,
    zatca_prefix TEXT,
    local_prefix TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(inv.zatca_start_invoice, 1) as zatca_current,
        COALESCE(inv.local_start_invoice, 1) as local_current,
        COALESCE(inv.zatca_prefix, 'ZATCA') as zatca_prefix,
        COALESCE(inv.local_prefix, 'LOCAL') as local_prefix
    FROM invoice_numbering inv
    WHERE inv.user_id = user_uuid;
END;
$$ LANGUAGE plpgsql;

-- 13. Create function to increment invoice numbers
CREATE OR REPLACE FUNCTION increment_invoice_number(
    user_uuid UUID,
    invoice_type TEXT
)
RETURNS INTEGER AS $$
DECLARE
    next_number INTEGER;
BEGIN
    IF invoice_type = 'zatca' THEN
        UPDATE invoice_numbering 
        SET zatca_start_invoice = zatca_start_invoice + 1
        WHERE user_id = user_uuid
        RETURNING zatca_start_invoice INTO next_number;
    ELSE
        UPDATE invoice_numbering 
        SET local_start_invoice = local_start_invoice + 1
        WHERE user_id = user_uuid
        RETURNING local_start_invoice INTO next_number;
    END IF;
    
    RETURN COALESCE(next_number, 1);
END;
$$ LANGUAGE plpgsql; 