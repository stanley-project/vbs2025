-- supabase/migrations/20250326183134_square_credit.sql
BEGIN;

-- Function to get teacher assignments with primary flag
CREATE OR REPLACE FUNCTION get_teacher_assignments()
RETURNS TABLE (
  teacher_name text,
  class_section text,
  student_count bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.name,
    cs.display_name,
    COUNT(v.id)
  FROM teachers t
  JOIN section_teachers st ON t.id = st.teacher_id
  JOIN class_sections cs ON st.section_id = cs.id
  LEFT JOIN vbs2025 v ON v.section_id = cs.id
  WHERE st.is_primary = true
  GROUP BY t.name, cs.display_name
  ORDER BY t.name, cs.display_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update section children function to show primary teacher
CREATE OR REPLACE FUNCTION get_section_children(p_section_id uuid)
RETURNS TABLE (
  child_id uuid,
  full_name text,
  parent_name text,
  class_section text,
  teacher_name text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    v.id as child_id,
    concat(v.first_name, ' ', v.last_name, ' ', v.surname) as full_name,
    v.parent_name,
    cs.display_name as class_section,
    t.name as teacher_name
  FROM vbs2025 v
  JOIN class_sections cs ON v.section_id = cs.id
  LEFT JOIN section_teachers st ON cs.id = st.section_id AND st.is_primary = true
  LEFT JOIN teachers t ON st.teacher_id = t.id
  WHERE v.section_id = p_section_id
  ORDER BY v.first_name, v.last_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update search children function to show primary teacher
CREATE OR REPLACE FUNCTION search_children(p_search_term text)
RETURNS TABLE (
  child_id uuid,
  full_name text,
  parent_name text,
  class_section text,
  teacher_name text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    v.id as child_id,
    concat(v.first_name, ' ', v.last_name, ' ', v.surname) as full_name,
    v.parent_name,
    cs.display_name as class_section,
    t.name as teacher_name
  FROM vbs2025 v
  JOIN class_sections cs ON v.section_id = cs.id
  LEFT JOIN section_teachers st ON cs.id = st.section_id AND st.is_primary = true
  LEFT JOIN teachers t ON st.teacher_id = t.id
  WHERE 
    v.first_name ILIKE '%' || p_search_term || '%'
    OR cs.display_name = p_search_term
  ORDER BY v.first_name, v.last_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update class counts function to show primary teacher
CREATE OR REPLACE FUNCTION get_class_counts()
RETURNS TABLE (
  class_id uuid,
  class_name text,
  total_count bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id as class_id,
    c.name as class_name,
    COUNT(v.id) as total_count
  FROM classes c
  LEFT JOIN vbs2025 v ON v.class_id = c.id
  GROUP BY c.id, c.name
  ORDER BY c.min_age;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_teacher_assignments() TO authenticated;
GRANT EXECUTE ON FUNCTION get_section_children(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION search_children(text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_class_counts() TO authenticated;

COMMIT;
