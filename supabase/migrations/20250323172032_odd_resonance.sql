/*
  # Optimize Database Schema
  
  1. Changes
    - Drop redundant class_allocations table
    - Replace acknowledgement counter with sequence
    - Add indexes for performance
    
  2. Security
    - Maintain existing RLS policies
*/

-- Begin transaction
BEGIN;

-- Create sequence for acknowledgement IDs
CREATE SEQUENCE IF NOT EXISTS acknowledgement_seq
  START WITH 100
  INCREMENT BY 1
  NO MAXVALUE;

-- Function to generate next acknowledgement ID using sequence
CREATE OR REPLACE FUNCTION generate_next_acknowledgement_id()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  next_number integer;
BEGIN
  -- Get next value from sequence
  SELECT nextval('acknowledgement_seq') INTO next_number;
  
  -- Format as 2025XXX
  RETURN '2025' || LPAD(next_number::text, 3, '0');
END;
$$;

-- Drop redundant class_allocations table
DROP TABLE IF EXISTS class_allocations CASCADE;

-- Add indexes for common queries
CREATE INDEX IF NOT EXISTS idx_vbs2025_class_section 
  ON vbs2025(class_id, section_id);

CREATE INDEX IF NOT EXISTS idx_vbs2025_age_lookup 
  ON vbs2025(age, created_at);

-- Drop acknowledgement_counter table since we now use a sequence
DROP TABLE IF EXISTS acknowledgement_counter CASCADE;

-- Update allocation function to work directly with vbs2025
CREATE OR REPLACE FUNCTION allocate_child_to_class()
RETURNS TRIGGER AS $$
DECLARE
  suitable_class_id uuid;
  suitable_section_id uuid;
BEGIN
  -- Find suitable class based on age
  SELECT c.id
  INTO suitable_class_id
  FROM classes c
  WHERE NEW.age BETWEEN c.min_age AND c.max_age
  AND EXISTS (
    SELECT 1 
    FROM class_sections cs
    LEFT JOIN vbs2025 v ON cs.id = v.section_id
    WHERE cs.class_id = c.id
    GROUP BY cs.id, cs.max_capacity
    HAVING COUNT(v.id) < cs.max_capacity
  )
  ORDER BY c.min_age
  LIMIT 1;

  -- If suitable class found, find least populated section
  IF suitable_class_id IS NOT NULL THEN
    SELECT cs.id
    INTO suitable_section_id
    FROM class_sections cs
    LEFT JOIN vbs2025 v ON cs.id = v.section_id
    WHERE cs.class_id = suitable_class_id
    GROUP BY cs.id, cs.max_capacity
    HAVING COUNT(v.id) < cs.max_capacity
    ORDER BY COUNT(v.id)::float / cs.max_capacity::float
    LIMIT 1;

    -- Update the record with class and section
    IF suitable_section_id IS NOT NULL THEN
      NEW.class_id := suitable_class_id;
      NEW.section_id := suitable_section_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger
DROP TRIGGER IF EXISTS trigger_allocate_child_to_class ON vbs2025;
CREATE TRIGGER trigger_allocate_child_to_class
  BEFORE INSERT ON vbs2025
  FOR EACH ROW
  EXECUTE FUNCTION allocate_child_to_class();

COMMIT;