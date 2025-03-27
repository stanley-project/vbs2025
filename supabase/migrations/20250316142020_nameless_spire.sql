/*
  # Fix acknowledgement ID generation

  1. Changes
    - Fix the generate_next_acknowledgement_id function to properly handle transactions
    - Add WHERE clause to UPDATE statement
*/

-- Drop existing function
DROP FUNCTION IF EXISTS generate_next_acknowledgement_id();

-- Create improved function
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
  SELECT id INTO counter_id FROM acknowledgement_counter LIMIT 1;
  
  -- Get and increment the counter with proper WHERE clause
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