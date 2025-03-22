/*
  # Fix Registration and Class Allocation Flow

  1. Changes
    - Add registration creation trigger for vbs2025
    - Fix class allocation logic to handle sections
    - Add function to find least populated section
    - Add function to handle unallocated children

  2. Security
    - Maintain existing RLS policies
*/

-- First, ensure we have the payment_amount column with a default value
ALTER TABLE registrations
ALTER COLUMN payment_amount SET DEFAULT 500.00;

-- Create function to automatically create registration record
CREATE OR REPLACE FUNCTION create_registration_for_child()
RETURNS TRIGGER AS $$
DECLARE
  v_registration_id uuid;
BEGIN
  -- Create registration record
  INSERT INTO registrations (
    child_id,
    year,
    payment_status,
    payment_amount
  ) VALUES (
    NEW.id,
    2025,
    NEW.payment_status,
    500.00
  ) RETURNING id INTO v_registration_id;

  -- Update the vbs2025 record with the registration_id
  NEW.registration_id := v_registration_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to create registration record
DROP TRIGGER IF EXISTS trigger_create_registration ON vbs2025;
CREATE TRIGGER trigger_create_registration
  BEFORE INSERT ON vbs2025
  FOR EACH ROW
  EXECUTE FUNCTION create_registration_for_child();

-- Drop and recreate the class allocation function with improved logic
DROP FUNCTION IF EXISTS allocate_child_to_class() CASCADE;

CREATE OR REPLACE FUNCTION allocate_child_to_class()
RETURNS TRIGGER AS $$
DECLARE
  suitable_class_id uuid;
  suitable_section_id uuid;
  child_age integer;
BEGIN
  -- Get child's age from vbs2025
  SELECT age INTO child_age
  FROM vbs2025
  WHERE id = NEW.child_id;

  IF child_age IS NULL THEN
    RAISE EXCEPTION 'Child age not found';
  END IF;

  -- Find suitable class based on age
  SELECT c.id
  INTO suitable_class_id
  FROM classes c
  WHERE child_age BETWEEN c.min_age AND c.max_age
  AND EXISTS (
    SELECT 1 
    FROM class_sections cs
    LEFT JOIN class_allocations ca ON cs.id = ca.section_id
    WHERE cs.class_id = c.id
    GROUP BY cs.id, cs.max_capacity
    HAVING COUNT(ca.id) < cs.max_capacity
  )
  ORDER BY c.min_age -- Ensure consistent class selection
  LIMIT 1;

  -- If suitable class found, find least populated section
  IF suitable_class_id IS NOT NULL THEN
    -- Find section with lowest enrollment ratio
    SELECT cs.id
    INTO suitable_section_id
    FROM class_sections cs
    LEFT JOIN class_allocations ca ON cs.id = ca.section_id
    WHERE cs.class_id = suitable_class_id
    GROUP BY cs.id, cs.max_capacity
    HAVING COUNT(ca.id) < cs.max_capacity
    ORDER BY COUNT(ca.id)::float / cs.max_capacity::float
    LIMIT 1;
    
    -- Create allocation if section found
    IF suitable_section_id IS NOT NULL THEN
      INSERT INTO class_allocations (registration_id, class_id, section_id)
      VALUES (NEW.id, suitable_class_id, suitable_section_id);
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger for automatic allocation
CREATE TRIGGER trigger_allocate_child_to_class
  AFTER INSERT ON registrations
  FOR EACH ROW
  EXECUTE FUNCTION allocate_child_to_class();

-- Function to allocate unallocated children
CREATE OR REPLACE FUNCTION allocate_unallocated_children()
RETURNS void AS $$
BEGIN
  -- Find and allocate each unallocated registration
  WITH unallocated_registrations AS (
    SELECT r.id as registration_id, r.child_id, v.age
    FROM registrations r
    LEFT JOIN class_allocations ca ON r.id = ca.registration_id
    JOIN vbs2025 v ON r.child_id = v.id
    WHERE ca.id IS NULL
  ),
  suitable_classes AS (
    SELECT 
      ur.registration_id,
      c.id as class_id,
      cs.id as section_id
    FROM unallocated_registrations ur
    JOIN classes c ON ur.age BETWEEN c.min_age AND c.max_age
    JOIN class_sections cs ON cs.class_id = c.id
    LEFT JOIN class_allocations ca ON cs.id = ca.section_id
    GROUP BY ur.registration_id, c.id, cs.id, cs.max_capacity
    HAVING COUNT(ca.id) < cs.max_capacity
    ORDER BY COUNT(ca.id)::float / cs.max_capacity::float
  )
  INSERT INTO class_allocations (registration_id, class_id, section_id)
  SELECT registration_id, class_id, section_id
  FROM suitable_classes;
END;
$$ LANGUAGE plpgsql;

-- Run allocation for existing unallocated children
SELECT allocate_unallocated_children();