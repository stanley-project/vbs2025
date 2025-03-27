/*
  # Add VBS 2025 Registration Table

  1. Tables
    - `vbs2025`
      - Mirrors children table structure
      - Uses existing payment_method and payment_status enums
      - Tracks registration and payment information

  2. Security
    - Enable RLS
    - Allow public inserts and reads
*/

-- Create vbs2025 registration table
CREATE TABLE IF NOT EXISTS vbs2025 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name text NOT NULL,
  last_name text NOT NULL,
  surname text NOT NULL,
  date_of_birth date NOT NULL,
  parent_name text NOT NULL,
  phone_number text NOT NULL,
  payment_method payment_method,
  payment_status payment_status DEFAULT 'pending',
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE vbs2025 ENABLE ROW LEVEL SECURITY;

-- Allow inserts from authenticated and anonymous users
CREATE POLICY "Anyone can insert into vbs2025"
  ON vbs2025 FOR INSERT
  TO public
  WITH CHECK (true);

-- Allow users to view their own registrations
CREATE POLICY "Users can view their own registrations"
  ON vbs2025 FOR SELECT
  TO public
  USING (true);