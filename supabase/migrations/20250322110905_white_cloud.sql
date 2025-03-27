/*
  # Update stored functions
  
  1. Changes
    - Remove references to registrations table
    - Update functions to work directly with vbs2025 table
    - Update class allocation logic
    - Update teacher dashboard queries
  
  2. Functions Updated
    - allocate_child_to_class
    - get_allocation_details
    - calculate_age
*/

-- Drop old functions and triggers
DROP FUNCTION IF EXISTS allocate_child_to_class() CASCADE;
DROP FUNCTION IF EXISTS get_allocation_details(uuid) CASCADE;

-- Create new allocation function that works directly with vbs2025
CREATE OR REPLACE FUNCTION allocate_child_to_class()
RETURNS TRIGGER AS $$
DECLARE
  suitable_class_id uuid;
  suitable_section_id uuid;
  section_count integer;
BEGIN
  -- Find suitable class based on age
  SELECT c.id
  INTO suitable_class_id
  FROM classes c
  WHERE NEW.age BETWEEN c.min_age AND c.max_age
  LIMIT 1;

  -- If suitable class found, find least populated section
  IF suitable_class_id IS NOT NULL THEN
    SELECT cs.id
    INTO suitable_section_id
    FROM class_sections cs
    LEFT JOIN vbs2025 v ON v.section_id = cs.id
    WHERE cs.class_id = suitable_class_id
    GROUP BY cs.id, cs.max_capacity
    HAVING COUNT(v.id) < cs.max_capacity
    ORDER BY COUNT(v.id)
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

-- Create trigger for automatic class allocation
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

-- Update age calculation function to handle null dates
CREATE OR REPLACE FUNCTION calculate_age()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.date_of_birth IS NOT NULL THEN
    NEW.age := DATE_PART('year', AGE(NEW.date_of_birth));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate age calculation trigger
DROP TRIGGER IF EXISTS set_age_on_vbs2025 ON vbs2025;
CREATE TRIGGER set_age_on_vbs2025
  BEFORE INSERT OR UPDATE OF date_of_birth
  ON vbs2025
  FOR EACH ROW
  EXECUTE FUNCTION calculate_age();