/*
  # Remove teacher_id from classes table
  
  1. Changes
    - Drop teacher_id column from classes table
    - Drop any policies that depend on teacher_id
    - Update RLS policies to use section_teachers table
*/

-- Begin transaction
BEGIN;

-- First drop any policies that might depend on teacher_id
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Teachers can view their classes" ON classes;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Remove teacher_id from classes table
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'classes' 
    AND column_name = 'teacher_id'
  ) THEN
    ALTER TABLE classes DROP COLUMN teacher_id;
  END IF;
END $$;

-- Create new policy for classes based on section assignments
CREATE POLICY "Teachers can view their classes"
  ON classes
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM class_sections cs
      JOIN section_teachers st ON cs.id = st.section_id
      WHERE cs.class_id = classes.id
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

COMMIT;