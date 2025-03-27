/*
  # Update VBS 2025 Schema and Class Assignment

  1. Changes
    - Add age column to vbs2025 table
    - Create trigger to automatically calculate age
    - Update class assignment algorithm to use vbs2025 table
    - Add foreign key relationships between tables

  2. Security
    - Maintain existing RLS policies
*/

-- Add age column to vbs2025 table
ALTER TABLE vbs2025
ADD COLUMN IF NOT EXISTS age integer;

-- Create function to calculate age
CREATE OR REPLACE FUNCTION calculate_age()
RETURNS TRIGGER AS $$
BEGIN
  NEW.age := DATE_PART('year', AGE(NEW.date_of_birth));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically calculate age
CREATE TRIGGER set_age_on_vbs2025
  BEFORE INSERT OR UPDATE OF date_of_birth
  ON vbs2025
  FOR EACH ROW
  EXECUTE FUNCTION calculate_age();

-- Update existing records with calculated age
UPDATE vbs2025
SET age = DATE_PART('year', AGE(date_of_birth));

-- Add registration_id column to vbs2025 if not exists
ALTER TABLE vbs2025
ADD COLUMN IF NOT EXISTS registration_id uuid REFERENCES registrations(id);

-- Update registrations table to reference vbs2025
ALTER TABLE registrations
DROP CONSTRAINT IF EXISTS registrations_child_id_vbs2024_fkey;

ALTER TABLE registrations
ADD CONSTRAINT registrations_child_id_vbs2025_fkey
FOREIGN KEY (child_id) REFERENCES vbs2025(id);

-- Drop old class assignment function and create new one
DROP FUNCTION IF EXISTS allocate_child_to_class() CASCADE;

CREATE OR REPLACE FUNCTION allocate_child_to_class()
RETURNS TRIGGER AS $$
DECLARE
  suitable_class_id uuid;
BEGIN
  -- Find suitable class with available capacity based on vbs2025 age
  SELECT c.id
  INTO suitable_class_id
  FROM classes c
  LEFT JOIN class_allocations ca ON c.id = ca.class_id
  WHERE EXISTS (
    SELECT 1 FROM vbs2025 v
    WHERE v.id = NEW.child_id
    AND v.age BETWEEN c.min_age AND c.max_age
  )
  GROUP BY c.id, c.max_capacity
  HAVING COUNT(ca.id) < c.max_capacity
  ORDER BY COUNT(ca.id)
  LIMIT 1;

  -- Create class allocation if suitable class found
  IF suitable_class_id IS NOT NULL THEN
    INSERT INTO class_allocations (registration_id, class_id)
    VALUES (NEW.id, suitable_class_id);
  END IF;

  -- Update vbs2025 record with registration_id
  UPDATE vbs2025
  SET registration_id = NEW.id
  WHERE id = NEW.child_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger for automatic class allocation
CREATE TRIGGER trigger_allocate_child_to_class
  AFTER INSERT ON registrations
  FOR EACH ROW
  EXECUTE FUNCTION allocate_child_to_class();