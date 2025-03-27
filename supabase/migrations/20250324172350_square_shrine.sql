/*
  # Fix Class Allocation Trigger

  1. Changes
    - Drop existing trigger and function
    - Create new trigger that runs BEFORE INSERT
    - Improve error handling and logging
    - Add proper transaction handling
*/

-- Begin transaction
BEGIN;

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS trigger_allocate_child_to_class ON vbs2025;
DROP FUNCTION IF EXISTS allocate_child_to_class();

-- Create new allocation function
CREATE OR REPLACE FUNCTION allocate_child_to_class()
RETURNS TRIGGER AS $$
DECLARE
  suitable_class_id uuid;
  suitable_section_id uuid;
  v_debug text;
BEGIN
  -- Debug information
  v_debug := 'Processing allocation for age: ' || NEW.age::text;
  RAISE NOTICE '%', v_debug;

  -- Find suitable class based on age
  SELECT c.id
  INTO suitable_class_id
  FROM classes c
  WHERE NEW.age BETWEEN c.min_age AND c.max_age
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
    RAISE WARNING 'No suitable class found for age %', NEW.age;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger that runs BEFORE INSERT
CREATE TRIGGER trigger_allocate_child_to_class
  BEFORE INSERT ON vbs2025
  FOR EACH ROW
  EXECUTE FUNCTION allocate_child_to_class();

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_vbs2025_age ON vbs2025(age);
CREATE INDEX IF NOT EXISTS idx_classes_age_range ON classes(min_age, max_age);
CREATE INDEX IF NOT EXISTS idx_sections_capacity ON class_sections(id, max_capacity);

-- Insert sample classes if none exist
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

COMMIT;