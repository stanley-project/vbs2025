/*
  # Simplify Registration Process

  1. Changes
    - Remove registrations table and related foreign keys
    - Add class_id and section_id directly to vbs2025 table
    - Update allocation trigger to work directly with vbs2025 table
    - Set payment_status to completed by default

  2. Security
    - Maintain RLS policies for vbs2025
*/

-- Begin transaction
BEGIN;

-- Add class and section references to vbs2025
ALTER TABLE vbs2025
ADD COLUMN IF NOT EXISTS class_id uuid REFERENCES classes(id),
ADD COLUMN IF NOT EXISTS section_id uuid REFERENCES class_sections(id);

-- Drop registrations table and related objects
DROP TABLE IF EXISTS registrations CASCADE;

-- Drop old allocation function and trigger
DROP FUNCTION IF EXISTS allocate_child_to_class() CASCADE;

-- Create new allocation function that works directly with vbs2025
CREATE OR REPLACE FUNCTION allocate_child_to_class()
RETURNS TRIGGER AS $$
DECLARE
  suitable_class_id uuid;
  suitable_section_id uuid;
BEGIN
  -- Find suitable class based on age
  WITH section_counts AS (
    SELECT 
      cs.id as section_id,
      cs.class_id,
      cs.max_capacity,
      COUNT(v.id) as current_count
    FROM class_sections cs
    LEFT JOIN vbs2025 v ON v.section_id = cs.id
    GROUP BY cs.id, cs.class_id, cs.max_capacity
  )
  SELECT c.id
  INTO suitable_class_id
  FROM classes c
  WHERE NEW.age BETWEEN c.min_age AND c.max_age
  AND EXISTS (
    SELECT 1 
    FROM section_counts sc
    WHERE sc.class_id = c.id
    AND sc.current_count < sc.max_capacity
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

  -- Set payment_status to completed by default
  NEW.payment_status := 'completed';

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to allocate class and section on insert
CREATE TRIGGER trigger_allocate_child_to_class
  BEFORE INSERT ON vbs2025
  FOR EACH ROW
  EXECUTE FUNCTION allocate_child_to_class();

-- Create function to get allocation details
CREATE OR REPLACE FUNCTION get_allocation_details(p_child_id uuid)
RETURNS TABLE (
  acknowledgement_id text,
  class_name text,
  section_name text,
  teacher_name text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    v.acknowledgement_id,
    c.name as class_name,
    cs.name as section_name,
    t.name as teacher_name
  FROM vbs2025 v
  LEFT JOIN classes c ON v.class_id = c.id
  LEFT JOIN class_sections cs ON v.section_id = cs.id
  LEFT JOIN teachers t ON cs.teacher_id = t.id
  WHERE v.id = p_child_id;
END;
$$ LANGUAGE plpgsql;

-- Update RLS policies
ALTER TABLE vbs2025 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable insert for public" ON vbs2025;
DROP POLICY IF EXISTS "Enable read for public" ON vbs2025;

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

COMMIT;