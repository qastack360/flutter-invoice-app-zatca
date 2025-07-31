-- Create invoices table (Basic version without RLS)
CREATE TABLE IF NOT EXISTS invoices (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL,
    invoice_number TEXT NOT NULL,
    invoice_prefix TEXT,
    invoice_date TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    salesman TEXT,
    vat_number TEXT,
    total_amount DECIMAL(10,2) NOT NULL,
    vat_amount DECIMAL(10,2),
    subtotal DECIMAL(10,2),
    discount DECIMAL(10,2),
    cash DECIMAL(10,2),
    items JSONB,
    company_details JSONB,
    zatca_invoice BOOLEAN DEFAULT false,
    zatca_uuid TEXT,
    zatca_environment TEXT,
    zatca_response JSONB,
    sync_status TEXT DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_invoices_user_id ON invoices(user_id);
CREATE INDEX IF NOT EXISTS idx_invoices_created_at ON invoices(created_at);
CREATE INDEX IF NOT EXISTS idx_invoices_zatca_invoice ON invoices(zatca_invoice);
CREATE INDEX IF NOT EXISTS idx_invoices_sync_status ON invoices(sync_status); 