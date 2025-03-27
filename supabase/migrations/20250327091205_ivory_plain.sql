-- /home/project/supabase/migrations/20250327091205_ivory_plain.sql

BEGIN;

-- Drop the function if it exists
DROP FUNCTION IF EXISTS get_teacher_assignments() CASCADE;

-- Create or replace get_teacher_assignments function to show all teachers
CREATE OR REPLACE FUNCTION get_teacher_assignments()
RETURNS TABLE (
  teacher_name text,
  class_section text,
  student_count bigint,
  is_primary boolean
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.name,
    cs.display_name,
    COUNT(v.id),
    st.is_primary
  FROM teachers t
  JOIN section_teachers st ON t.id = st.teacher_id
  JOIN class_sections cs ON st.section_id = cs.id
  LEFT JOIN vbs2025 v ON v.section_id = cs.id
  GROUP BY t.name, cs.display_name, st.is_primary
  ORDER BY t.name, cs.display_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_teacher_assignments() TO authenticated;

COMMIT;
