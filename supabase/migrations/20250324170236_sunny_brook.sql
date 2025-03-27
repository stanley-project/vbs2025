/*
  # Revert to Acknowledgement Counter Table
  
  1. Changes
    - Drop existing sequence
    - Create acknowledgement_counter table
    - Update generate_next_acknowledgement_id function
    
  2. Security
    - Maintain existing RLS policies
*/

-- Begin transaction
BEGIN;

-- Drop the existing sequence if it exists
DROP SEQUENCE IF EXISTS acknowledgement_seq;

-- Create acknowledgement counter table
CREATE TABLE IF NOT EXISTS acknowledgement_counter (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  last_used_number integer DEFAULT 0,
  updated_at timestamptz DEFAULT now()
);

-- Insert initial counter if table is empty
INSERT INTO acknowledgement_counter (id, last_used_number)
SELECT gen_random_uuid(), 0
WHERE NOT EXISTS (SELECT 1 FROM acknowledgement_counter);

-- Drop existing function
DROP FUNCTION IF EXISTS generate_next_acknowledgement_id();

-- Create new function using counter table
CREATE OR REPLACE FUNCTION generate_next_acknowledgement_id()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  next_number integer;
  next_id text;
  counter_id uuid;
BEGIN
  -- Get the counter ID (we expect only one row)
  SELECT id INTO counter_id 
  FROM acknowledgement_counter 
  LIMIT 1;
  
  -- Get and increment the counter with proper locking
  UPDATE acknowledgement_counter
  SET last_used_number = last_used_number + 1,
      updated_at = now()
  WHERE id = counter_id
  RETURNING last_used_number INTO next_number;

  -- Format the ID as 2025XXX where XXX is the incremented number
  next_id := '2025' || LPAD(next_number::text, 3, '0');
  
  RETURN next_id;
END;
$$;

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_vbs2025_acknowledgement_id 
ON vbs2025(acknowledgement_id);

COMMIT;