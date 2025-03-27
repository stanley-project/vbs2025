/*
  # Fix Acknowledgement ID and Class Allocation

  1. Changes
    - Reset acknowledgement sequence to start from 1
    - Fix class allocation logic
    - Add better error handling and logging
*/

-- Begin transaction
BEGIN;

-- Drop existing sequence and recreate it starting from 1
DROP SEQUENCE IF EXISTS acknowledgement_seq;

CREATE SEQUENCE acknowledgement_seq
  START WITH 1
  INCREMENT BY 1
  NO MAXVALUE;

-- Update the function to generate acknowledgement IDs
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
  
  -- Format as 2025XXX where XXX is padded with leading zeros
  RETURN '2025' || LPAD(next_number::text, 3, '0');
END;
$$;

-- Drop existing allocation function and recreate with better logic
DROP FUNCTION IF EXISTS allocate_child_to_class() CASCADE;

CREATE OR REPLACE FUNCTION allocate_child_to_class()
RETURNS TRIGGER AS $$
DECLARE
  suitable_class_id uuid;
  suitable_section_id uuid;
  v_age integer;
  v_debug text;
BEGIN
  -- Calculate and store age
  v_age := NEW.age;
  
  -- Debug information
  v_debug := 'Processing allocation for age: ' || v_age::text;
  RAISE NOTICE '%', v_debug;

  -- Find suitable class based on age
  SELECT c.id
  INTO suitable_class_id
  FROM classes c
  WHERE v_age BETWEEN c.min_age AND c.max_age
  ORDER BY c.min_age
  LIMIT 1;

  v_debug := 'Found class_id: ' || suitable_class_id::text;
  RAISE NOTICE '%', v_debug;

  -- If suitable class found, find least populated section
  IF suitable_class_id IS NOT NULL THEN
    SELECT cs.id
    INTO suitable_section_id
    FROM class_sections cs
    LEFT JOIN vbs2025 v ON cs.id = v.section_id
    WHERE cs.class_id = suitable_class_id
    GROUP BY cs.id, cs.max_capacity
    HAVING COUNT(v.id) < cs.max_capacity
    ORDER BY COUNT(v.id)
    LIMIT 1;

    v_debug := 'Found section_id: ' || suitable_section_id::text;
    RAISE NOTICE '%', v_debug;

    -- Update the record with class and section
    IF suitable_section_id IS NOT NULL THEN
      NEW.class_id := suitable_class_id;
      NEW.section_id := suitable_section_id;
    ELSE
      RAISE WARNING 'No available sections found in class %', suitable_class_id;
    END IF;
  ELSE
    RAISE WARNING 'No suitable class found for age %', v_age;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
CREATE TRIGGER trigger_allocate_child_to_class
  BEFORE INSERT ON vbs2025
  FOR EACH ROW
  EXECUTE FUNCTION allocate_child_to_class();

-- Insert sample data for testing if tables are empty
DO $$
BEGIN
  -- Insert classes if none exist
  IF NOT EXISTS (SELECT 1 FROM classes) THEN
    INSERT INTO classes (name, min_age, max_age) VALUES
      ('Beginners', 3, 5),
      ('Primary', 6, 8),
      ('Junior', 9, 11),
      ('Senior', 12, 14);
  END IF;

  -- Insert sections for each class if none exist
  IF NOT EXISTS (SELECT 1 FROM class_sections) THEN
    INSERT INTO class_sections (class_id, name, section_code, max_capacity)
    SELECT 
      c.id,
      c.name,
      code,
      30
    FROM classes c
    CROSS JOIN (VALUES ('A'), ('B')) AS codes(code)
    ON CONFLICT DO NOTHING;
  END IF;
END $$;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_vbs2025_age ON vbs2025(age);
CREATE INDEX IF NOT EXISTS idx_classes_age_range ON classes(min_age, max_age);
CREATE INDEX IF NOT EXISTS idx_sections_capacity ON class_sections(id, max_capacity);

COMMIT;