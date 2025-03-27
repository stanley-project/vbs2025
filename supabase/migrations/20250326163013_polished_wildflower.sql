/*
  # Update Teacher Assignment Schema and Functions
  
  1. Changes
    - Remove role column from display
    - Update student count function to include all sections
    - Add indexes for better performance
*/

-- Drop the existing function
DROP FUNCTION IF EXISTS count_students_by_section();

-- Create new function that includes all sections
CREATE OR REPLACE FUNCTION count_students_by_section()
RETURNS TABLE (
  section_id uuid,
  student_count bigint
)
LANGUAGE sql
AS $$
  WITH all_sections AS (
    SELECT id FROM class_sections
  )
  SELECT 
    s.id as section_id,
    COUNT(v.id) as student_count
  FROM all_sections s
  LEFT JOIN vbs2025 v ON v.section_id = s.id
  GROUP BY s.id;
$$;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_vbs2025_section_id ON vbs2025(section_id);