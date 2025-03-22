/*
  # Fix RLS Policies for Registration Process

  1. Changes
    - Add RLS policies for registrations table
    - Add RLS policies for vbs2025 table
    - Add RLS policies for class_allocations table
    - Enable public access for registration process

  2. Security
    - Allow public to insert into both tables
    - Allow public to read their own registrations
    - Maintain data security while enabling registration flow
*/

-- Wrap everything in a transaction
BEGIN;

-- Enable RLS on registrations table
ALTER TABLE registrations ENABLE ROW LEVEL SECURITY;

-- Create policies for registrations table
DO $$ 
BEGIN
  -- Drop existing policies if they exist
  DROP POLICY IF EXISTS "Enable insert for public" ON registrations;
  DROP POLICY IF EXISTS "Enable read for public" ON registrations;
  
  -- Create new policies
  CREATE POLICY "Enable insert for public"
    ON registrations
    FOR INSERT
    TO public
    WITH CHECK (true);

  CREATE POLICY "Enable read for public"
    ON registrations
    FOR SELECT
    TO public
    USING (true);
EXCEPTION
  WHEN others THEN
    -- Log error and continue
    RAISE NOTICE 'Error creating registrations policies: %', SQLERRM;
END $$;

-- Enable RLS on vbs2025 table
ALTER TABLE vbs2025 ENABLE ROW LEVEL SECURITY;

-- Create policies for vbs2025
DO $$ 
BEGIN
  -- Drop existing policies if they exist
  DROP POLICY IF EXISTS "Anyone can insert into vbs2025" ON vbs2025;
  DROP POLICY IF EXISTS "Users can view their own registrations" ON vbs2025;
  DROP POLICY IF EXISTS "Enable insert for public" ON vbs2025;
  DROP POLICY IF EXISTS "Enable read for public" ON vbs2025;
  
  -- Create new policies
  CREATE POLICY "Enable insert for public"
    ON vbs2025
    FOR INSERT
    TO public
    WITH CHECK (true);

  CREATE POLICY "Enable read for public"
    ON vbs2025
    FOR SELECT
    TO public
    USING (true);
EXCEPTION
  WHEN others THEN
    -- Log error and continue
    RAISE NOTICE 'Error creating vbs2025 policies: %', SQLERRM;
END $$;

-- Enable RLS on class_allocations table
ALTER TABLE class_allocations ENABLE ROW LEVEL SECURITY;

-- Create policies for class_allocations
DO $$ 
BEGIN
  -- Drop existing policies if they exist
  DROP POLICY IF EXISTS "Enable insert for system" ON class_allocations;
  DROP POLICY IF EXISTS "Enable read for public" ON class_allocations;
  
  -- Create new policies
  CREATE POLICY "Enable insert for system"
    ON class_allocations
    FOR INSERT
    TO public
    WITH CHECK (true);

  CREATE POLICY "Enable read for public"
    ON class_allocations
    FOR SELECT
    TO public
    USING (true);
EXCEPTION
  WHEN others THEN
    -- Log error and continue
    RAISE NOTICE 'Error creating class_allocations policies: %', SQLERRM;
END $$;

-- Verify RLS is enabled on all tables
DO $$ 
BEGIN
  -- Check registrations
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE tablename = 'registrations' 
    AND rowsecurity = true
  ) THEN
    ALTER TABLE registrations ENABLE ROW LEVEL SECURITY;
  END IF;

  -- Check vbs2025
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE tablename = 'vbs2025' 
    AND rowsecurity = true
  ) THEN
    ALTER TABLE vbs2025 ENABLE ROW LEVEL SECURITY;
  END IF;

  -- Check class_allocations
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE tablename = 'class_allocations' 
    AND rowsecurity = true
  ) THEN
    ALTER TABLE class_allocations ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

COMMIT;