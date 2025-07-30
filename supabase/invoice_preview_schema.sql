-- Invoice Preview and Printer Status Schema
-- Run this in Supabase SQL Editor

-- 1. Create invoice_previews table for storing preview data
CREATE TABLE IF NOT EXISTS invoice_previews (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    invoice_id TEXT NOT NULL,
    invoice_number INTEGER NOT NULL,
    invoice_prefix TEXT NOT NULL,
    preview_data JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create printer_status table for tracking printer connections
CREATE TABLE IF NOT EXISTS printer_status (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    printer_mac TEXT,
    printer_name TEXT,
    is_connected BOOLEAN DEFAULT false,
    last_connected TIMESTAMP WITH TIME ZONE,
    connection_attempts INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create print_logs table for tracking print activities
CREATE TABLE IF NOT EXISTS print_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    invoice_id TEXT NOT NULL,
    invoice_number INTEGER NOT NULL,
    print_status TEXT NOT NULL CHECK (print_status IN ('success', 'failed', 'pending')),
    printer_mac TEXT,
    error_message TEXT,
    print_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_invoice_previews_user_id ON invoice_previews(user_id);
CREATE INDEX IF NOT EXISTS idx_invoice_previews_invoice_id ON invoice_previews(invoice_id);
CREATE INDEX IF NOT EXISTS idx_printer_status_user_id ON printer_status(user_id);
CREATE INDEX IF NOT EXISTS idx_print_logs_user_id ON print_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_print_logs_invoice_id ON print_logs(invoice_id);
CREATE INDEX IF NOT EXISTS idx_print_logs_status ON print_logs(print_status);

-- 5. Create triggers for automatic timestamp updates
CREATE TRIGGER update_invoice_previews_updated_at BEFORE UPDATE ON invoice_previews
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_printer_status_updated_at BEFORE UPDATE ON printer_status
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 6. Enable RLS for new tables
ALTER TABLE invoice_previews ENABLE ROW LEVEL SECURITY;
ALTER TABLE printer_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE print_logs ENABLE ROW LEVEL SECURITY;

-- 7. Create RLS policies for invoice_previews
CREATE POLICY "Users can view their own invoice previews" ON invoice_previews
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own invoice previews" ON invoice_previews
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own invoice previews" ON invoice_previews
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own invoice previews" ON invoice_previews
    FOR DELETE USING (auth.uid() = user_id);

-- 8. Create RLS policies for printer_status
CREATE POLICY "Users can view their own printer status" ON printer_status
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own printer status" ON printer_status
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own printer status" ON printer_status
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own printer status" ON printer_status
    FOR DELETE USING (auth.uid() = user_id);

-- 9. Create RLS policies for print_logs
CREATE POLICY "Users can view their own print logs" ON print_logs
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own print logs" ON print_logs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own print logs" ON print_logs
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own print logs" ON print_logs
    FOR DELETE USING (auth.uid() = user_id);

-- 10. Create views for easier data access
CREATE OR REPLACE VIEW invoice_preview_summary AS
SELECT 
    ip.id,
    ip.invoice_id,
    ip.invoice_number,
    ip.invoice_prefix,
    ip.created_at,
    u.email as user_email
FROM invoice_previews ip
JOIN auth.users u ON ip.user_id = u.id;

CREATE OR REPLACE VIEW print_status_summary AS
SELECT 
    ps.user_id,
    ps.printer_name,
    ps.is_connected,
    ps.last_connected,
    ps.connection_attempts,
    u.email as user_email
FROM printer_status ps
JOIN auth.users u ON ps.user_id = u.id;

CREATE OR REPLACE VIEW print_logs_summary AS
SELECT 
    pl.invoice_id,
    pl.invoice_number,
    pl.print_status,
    pl.printer_mac,
    pl.print_timestamp,
    u.email as user_email
FROM print_logs pl
JOIN auth.users u ON pl.user_id = u.id;

-- 11. Create functions for printer management
CREATE OR REPLACE FUNCTION update_printer_connection(
    user_uuid UUID,
    printer_mac TEXT,
    printer_name TEXT,
    is_connected BOOLEAN
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO printer_status (user_id, printer_mac, printer_name, is_connected, last_connected)
    VALUES (user_uuid, printer_mac, printer_name, is_connected, 
            CASE WHEN is_connected THEN NOW() ELSE NULL END)
    ON CONFLICT (user_id) 
    DO UPDATE SET 
        printer_mac = EXCLUDED.printer_mac,
        printer_name = EXCLUDED.printer_name,
        is_connected = EXCLUDED.is_connected,
        last_connected = CASE WHEN EXCLUDED.is_connected THEN NOW() ELSE printer_status.last_connected END,
        connection_attempts = CASE WHEN EXCLUDED.is_connected THEN 0 ELSE printer_status.connection_attempts + 1 END,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- 12. Create function to log print activities
CREATE OR REPLACE FUNCTION log_print_activity(
    user_uuid UUID,
    invoice_id TEXT,
    invoice_number INTEGER,
    print_status TEXT,
    printer_mac TEXT DEFAULT NULL,
    error_message TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO print_logs (user_id, invoice_id, invoice_number, print_status, printer_mac, error_message)
    VALUES (user_uuid, invoice_id, invoice_number, print_status, printer_mac, error_message);
END;
$$ LANGUAGE plpgsql;

-- 13. Create function to get printer connection status
CREATE OR REPLACE FUNCTION get_printer_status(user_uuid UUID)
RETURNS TABLE(
    is_connected BOOLEAN,
    printer_name TEXT,
    printer_mac TEXT,
    last_connected TIMESTAMP WITH TIME ZONE,
    connection_attempts INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(ps.is_connected, false) as is_connected,
        ps.printer_name,
        ps.printer_mac,
        ps.last_connected,
        COALESCE(ps.connection_attempts, 0) as connection_attempts
    FROM printer_status ps
    WHERE ps.user_id = user_uuid;
END;
$$ LANGUAGE plpgsql; 