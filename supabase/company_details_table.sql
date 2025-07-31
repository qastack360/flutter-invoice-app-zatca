-- Create company_details table
CREATE TABLE IF NOT EXISTS company_details (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL,
    owner_name1 TEXT,
    owner_name2 TEXT,
    other_name TEXT,
    phone TEXT,
    vat_no TEXT,
    cr_number TEXT,
    address TEXT,
    city TEXT,
    email TEXT,
    logo_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index on user_id for faster queries
CREATE INDEX IF NOT EXISTS idx_company_details_user_id ON company_details(user_id);

-- Enable Row Level Security (RLS)
ALTER TABLE company_details ENABLE ROW LEVEL SECURITY;

-- Create policy to allow users to access only their own company details
CREATE POLICY "Users can view their own company details" ON company_details
    FOR SELECT USING (auth.uid()::text = user_id OR user_id = 'default');

-- Create policy to allow users to insert their own company details
CREATE POLICY "Users can insert their own company details" ON company_details
    FOR INSERT WITH CHECK (auth.uid()::text = user_id OR user_id = 'default');

-- Create policy to allow users to update their own company details
CREATE POLICY "Users can update their own company details" ON company_details
    FOR UPDATE USING (auth.uid()::text = user_id OR user_id = 'default');

-- Create policy to allow users to delete their own company details
CREATE POLICY "Users can delete their own company details" ON company_details
    FOR DELETE USING (auth.uid()::text = user_id OR user_id = 'default');

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_company_details_updated_at 
    BEFORE UPDATE ON company_details 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column(); 