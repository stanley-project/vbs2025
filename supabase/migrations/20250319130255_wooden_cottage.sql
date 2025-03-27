/*
  # Add role to teachers table

  1. Changes
    - Add role column to teachers table
    - Add phone column if not exists
    - Update RLS policies for teacher authentication
*/

-- Add role column to teachers table if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'teachers' AND column_name = 'role'
  ) THEN
    ALTER TABLE teachers 
    ADD COLUMN role text NOT NULL DEFAULT 'teacher' 
    CHECK (role IN ('teacher', 'admin'));
  END IF;
END $$;

-- Add phone column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'teachers' AND column_name = 'phone'
  ) THEN
    ALTER TABLE teachers 
    ADD COLUMN phone text;
  END IF;
END $$;

-- Update RLS policies
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;

-- Allow teachers to read their own data
-- Update the policy to use phone number directly
CREATE OR REPLACE POLICY "Teachers can read their own data"
  ON teachers
  FOR SELECT
  TO authenticated
  USING (phone = auth.jwt()->>'phone');