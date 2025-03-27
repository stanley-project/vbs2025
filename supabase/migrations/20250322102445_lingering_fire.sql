/*
  # Implement Class and Section Allocation System

  1. Changes
    - Add class_sections table
    - Update class_allocations table to include section_id
    - Create function to find least populated section
    - Update allocation function to handle sections

  2. Security
    - Enable RLS on class_sections table
    - Add policies for teachers to view their sections
*/

-- Create class_sections table if not exists
CREATE TABLE IF NOT EXISTS class_sections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id uuid REFERENCES classes(id),
  name text NOT NULL,
  teacher_id uuid REFERENCES teachers(id),
  max_capacity integer NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(class_id, name)
);

-- Enable RLS on class_sections
ALTER TABLE class_sections ENABLE ROW LEVEL SECURITY;

-- Add section_id to class_allocations if not exists
ALTER TABLE class_allocations
ADD COLUMN IF NOT EXISTS section_id uuid REFERENCES class_sections(id);

-- Create policy for teachers to view their sections
CREATE POLICY "Teachers can view their sections"
  ON class_sections
  FOR SELECT
  TO authenticated
  USING (teacher_id = auth.uid());

-- Function to find least populated section in a class
CREATE OR REPLACE FUNCTION find_least_populated_section(p_class_id uuid)
RETURNS uuid AS $$
DECLARE
  v_section_id uuid;
BEGIN
  -- Get section with lowest enrollment ratio
  SELECT cs.id
  INTO v_section_id
  FROM class_sections cs
  LEFT JOIN class_allocations ca ON cs.id = ca.section_id
  WHERE cs.class_id = p_class_id
  GROUP BY cs.id, cs.max_capacity
  HAVING COUNT(ca.id) < cs.max_capacity
  ORDER BY COUNT(ca.id)::float / cs.max_capacity::float
  LIMIT 1;

  RETURN v_section_id;
END;
$$ LANGUAGE plpgsql;

-- Drop existing allocation function and trigger
DROP TRIGGER IF EXISTS trigger_allocate_child_to_class ON registrations CASCADE;
DROP FUNCTION IF EXISTS allocate_child_to_class() CASCADE;

-- Create new allocation function that handles sections
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
  LIMIT 1;

  -- If suitable class found, find least populated section
  IF suitable_class_id IS NOT NULL THEN
    suitable_section_id := find_least_populated_section(suitable_class_id);
    
    -- Create allocation if section found
    IF suitable_section_id IS NOT NULL THEN
      INSERT INTO class_allocations (registration_id, class_id, section_id)
      VALUES (NEW.id, suitable_class_id, suitable_section_id);
    END IF;
  END IF;

  -- Update vbs2025 record with registration_id
  UPDATE vbs2025
  SET registration_id = NEW.id
  WHERE id = NEW.child_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic allocation
CREATE TRIGGER trigger_allocate_child_to_class
  AFTER INSERT ON registrations
  FOR EACH ROW
  EXECUTE FUNCTION allocate_child_to_class();

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_class_allocations_section_id ON class_allocations(section_id);
CREATE INDEX IF NOT EXISTS idx_class_sections_class_id ON class_sections(class_id);
CREATE INDEX IF NOT EXISTS idx_class_sections_teacher_id ON class_sections(teacher_id);

-- Update existing allocations to use sections
DO $$ 
DECLARE
  r RECORD;
BEGIN
  -- For each allocation without a section
  FOR r IN 
    SELECT * FROM class_allocations 
    WHERE section_id IS NULL
  LOOP
    -- Find and assign least populated section
    UPDATE class_allocations
    SET section_id = find_least_populated_section(class_id)
    WHERE id = r.id;
  END LOOP;
END $$;