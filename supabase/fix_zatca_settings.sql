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