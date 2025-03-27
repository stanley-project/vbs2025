/*
  # Update Class and Section Schema for Multiple Teachers
  
  1. New Tables
    - section_teachers: Junction table for multiple teachers per section
  
  2. Changes
    - Add section_code and display_name to class_sections
    - Remove teacher_id from class_sections (with proper dependency handling)
    - Update allocation functions
  
  3. Security
    - Enable RLS on new tables
    - Add policies for teacher access
*/

-- Begin transaction
BEGIN;

-- Create enum type for section roles if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'section_role') THEN
    CREATE TYPE section_role AS ENUM ('primary', 'assistant');
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Create section_teachers table
CREATE TABLE IF NOT EXISTS section_teachers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  section_id uuid NOT NULL,
  teacher_id uuid NOT NULL,
  is_primary boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT fk_section
    FOREIGN KEY (section_id)
    REFERENCES class_sections(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_teacher
    FOREIGN KEY (teacher_id)
    REFERENCES teachers(id)
    ON DELETE CASCADE,
  CONSTRAINT unique_section_teacher 
    UNIQUE(section_id, teacher_id)
);

-- First drop the existing policy that depends on teacher_id
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Teachers can view their sections" ON class_sections;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Safely remove teacher_id from class_sections
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'class_sections' 
    AND column_name = 'teacher_id'
  ) THEN
    -- First, migrate existing teacher assignments to junction table
    INSERT INTO section_teachers (section_id, teacher_id, is_primary)
    SELECT id, teacher_id, true
    FROM class_sections
    WHERE teacher_id IS NOT NULL
    ON CONFLICT (section_id, teacher_id) DO NOTHING;
    
    -- Then drop the column
    ALTER TABLE class_sections DROP COLUMN teacher_id;
  END IF;
END $$;

-- Add new columns to class_sections
ALTER TABLE class_sections
ADD COLUMN IF NOT EXISTS section_code text;

-- Update existing sections with default section codes
UPDATE class_sections
SET section_code = 'A'
WHERE section_code IS NULL;

-- Make section_code NOT NULL after setting defaults
ALTER TABLE class_sections
ALTER COLUMN section_code SET NOT NULL;

-- Add display_name as generated column
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'class_sections' 
    AND column_name = 'display_name'
  ) THEN
    ALTER TABLE class_sections
    ADD COLUMN display_name text GENERATED ALWAYS AS (
      CASE 
        WHEN section_code = 'MAIN' THEN name
        ELSE name || '-' || section_code
      END
    ) STORED;
  END IF;
END $$;

-- Add unique constraint for class + section code
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'unique_class_section_code'
  ) THEN
    ALTER TABLE class_sections
    ADD CONSTRAINT unique_class_section_code 
    UNIQUE (class_id, section_code);
  END IF;
END $$;

-- Enable RLS on section_teachers
ALTER TABLE section_teachers ENABLE ROW LEVEL SECURITY;

-- Create new policy for class_sections based on section_teachers
CREATE POLICY "Teachers can view their sections"
  ON class_sections
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM section_teachers st
      WHERE st.section_id = class_sections.id
      AND (
        st.teacher_id = auth.uid() OR
        EXISTS (
          SELECT 1 FROM teachers
          WHERE teachers.id = st.teacher_id
          AND teachers.role = 'admin'
        )
      )
    )
  );

-- Create policies for section_teachers
CREATE POLICY "Teachers can view their section assignments"
  ON section_teachers
  FOR SELECT
  TO authenticated
  USING (
    teacher_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM teachers
      WHERE teachers.id = section_teachers.teacher_id
      AND teachers.role = 'admin'
    )
  );

-- Update find_least_populated_section function
CREATE OR REPLACE FUNCTION find_least_populated_section(p_class_id uuid)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_section_id uuid;
BEGIN
  SELECT cs.id
  INTO v_section_id
  FROM class_sections cs
  LEFT JOIN vbs2025 v ON cs.id = v.section_id
  WHERE cs.class_id = p_class_id
  GROUP BY cs.id, cs.max_capacity
  HAVING COUNT(v.id) < cs.max_capacity
  ORDER BY 
    COUNT(v.id)::float / cs.max_capacity::float,
    cs.section_code
  LIMIT 1;

  RETURN v_section_id;
END;
$$;

-- Update allocation function
CREATE OR REPLACE FUNCTION allocate_child_to_class()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
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
    LEFT JOIN vbs2025 v ON v.section_id = cs.id
    WHERE cs.class_id = c.id
    GROUP BY cs.id, cs.max_capacity
    HAVING COUNT(v.id) < cs.max_capacity
  )
  ORDER BY c.min_age
  LIMIT 1;

  IF suitable_class_id IS NOT NULL THEN
    suitable_section_id := find_least_populated_section(suitable_class_id);
    
    IF suitable_section_id IS NOT NULL THEN
      NEW.class_id := suitable_class_id;
      NEW.section_id := suitable_section_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Create section details function
CREATE OR REPLACE FUNCTION get_section_details(p_section_id uuid)
RETURNS TABLE (
  section_name text,
  section_code text,
  display_name text,
  teacher_names text[],
  primary_teacher_name text,
  current_students bigint,
  max_capacity integer
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cs.name as section_name,
    cs.section_code,
    cs.display_name,
    ARRAY_AGG(DISTINCT t.name) FILTER (WHERE t.name IS NOT NULL) as teacher_names,
    (
      SELECT t2.name 
      FROM section_teachers st2
      JOIN teachers t2 ON t2.id = st2.teacher_id
      WHERE st2.section_id = cs.id AND st2.is_primary
      LIMIT 1
    ) as primary_teacher_name,
    COUNT(v.id) as current_students,
    cs.max_capacity
  FROM class_sections cs
  LEFT JOIN section_teachers st ON cs.id = st.section_id
  LEFT JOIN teachers t ON t.id = st.teacher_id
  LEFT JOIN vbs2025 v ON v.section_id = cs.id
  WHERE cs.id = p_section_id
  GROUP BY cs.id, cs.name, cs.section_code, cs.display_name, cs.max_capacity;
END;
$$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_section_teachers_section_id 
  ON section_teachers(section_id);
CREATE INDEX IF NOT EXISTS idx_section_teachers_teacher_id 
  ON section_teachers(teacher_id);
CREATE INDEX IF NOT EXISTS idx_class_sections_section_code 
  ON class_sections(section_code);

COMMIT;