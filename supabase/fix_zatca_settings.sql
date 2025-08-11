-- Fix zatca_settings table - Add missing columns
-- Run this in Supabase SQL Editor

-- Add missing columns to zatca_settings table
ALTER TABLE zatca_settings ADD COLUMN IF NOT EXISTS vat_number TEXT;
ALTER TABLE zatca_settings ADD COLUMN IF NOT EXISTS cr_number TEXT;
ALTER TABLE zatca_settings ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE zatca_settings ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE zatca_settings ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE zatca_settings ADD COLUMN IF NOT EXISTS email TEXT;

-- Update existing zatca_settings table structure to match the app requirements
-- This ensures all fields from the ZATCA Settings screen are available

-- Verify the table structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'zatca_settings' 
ORDER BY ordinal_position; 

-- Migration script to add missing fields to invoices table
-- Run this in Supabase SQL editor

-- Add missing columns to invoices table
ALTER TABLE invoices 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS invoice_prefix TEXT,
ADD COLUMN IF NOT EXISTS subtotal DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS discount DECIMAL(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS cash DECIMAL(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS vat_percent DECIMAL(5,2) DEFAULT 15.0,
ADD COLUMN IF NOT EXISTS zatca_invoice BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS zatca_environment TEXT DEFAULT 'sandbox';

-- Update existing records to have default values
UPDATE invoices 
SET 
    user_id = COALESCE(user_id, '00000000-0000-0000-0000-000000000000'),
    invoice_prefix = COALESCE(invoice_prefix, 'INV'),
    subtotal = COALESCE(subtotal, total_amount - vat_amount),
    discount = COALESCE(discount, 0),
    cash = COALESCE(cash, total_amount),
    vat_percent = COALESCE(vat_percent, 15.0),
    zatca_invoice = COALESCE(zatca_invoice, false),
    zatca_environment = COALESCE(zatca_environment, 'sandbox')
WHERE user_id IS NULL OR invoice_prefix IS NULL OR subtotal IS NULL OR discount IS NULL OR cash IS NULL OR vat_percent IS NULL OR zatca_invoice IS NULL OR zatca_environment IS NULL;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_invoices_zatca_invoice ON invoices(zatca_invoice);
CREATE INDEX IF NOT EXISTS idx_invoices_zatca_environment ON invoices(zatca_environment); 