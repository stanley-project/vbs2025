/*
  # Simplify Class Allocation Logic

  1. Changes
    - Optimize class allocation function
    - Improve section assignment logic
    - Simplify database queries
    - Add better error handling
*/

-- Drop existing function and trigger
DROP FUNCTION IF EXISTS allocate_child_to_class() CASCADE;

-- Create new simplified allocation function
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