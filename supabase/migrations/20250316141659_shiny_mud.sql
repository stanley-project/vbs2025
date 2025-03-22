/*
  # Add Acknowledgement ID System

  1. New Tables
    - acknowledgement_counter
      - Tracks the last used acknowledgement number
      - Used to generate sequential IDs

  2. Functions
    - generate_next_acknowledgement_id()
      - Generates the next sequential acknowledgement ID
      - Uses counter table to ensure uniqueness
*/

-- Create acknowledgement counter table
CREATE TABLE IF NOT EXISTS acknowledgement_counter (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  last_used_number integer DEFAULT 99,
  updated_at timestamptz DEFAULT now()
);

-- Insert initial counter if table is empty
INSERT INTO acknowledgement_counter (id, last_used_number)
SELECT gen_random_uuid(), 99
WHERE NOT EXISTS (SELECT 1 FROM acknowledgement_counter);

-- Function to generate next acknowledgement ID
CREATE OR REPLACE FUNCTION generate_next_acknowledgement_id()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  next_number integer;
  next_id text;
BEGIN
  -- Get and increment the counter in a transaction
  UPDATE acknowledgement_counter
  SET last_used_number = last_used_number + 1,
      updated_at = now()
  RETURNING last_used_number INTO next_number;

  -- Format the ID as 2025XXX where XXX is the incremented number
  next_id := '2025' || LPAD(next_number::text, 3, '0');
  
  RETURN next_id;
END;
$$;