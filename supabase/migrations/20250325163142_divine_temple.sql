/*
  # Fix Admin Dashboard Schema and Queries
  
  1. Changes
    - Add missing indexes for performance
    - Add helper functions for admin dashboard
    - Fix class and section relationships
*/

BEGIN;

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_vbs2025_section_id ON vbs2025(section_id);
CREATE INDEX IF NOT EXISTS idx_vbs2025_class_id ON vbs2025(class_id);
CREATE INDEX IF NOT EXISTS idx_class_sections_class_id ON class_sections(class_id);

-- Function to get class counts
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

-- Function to get section counts for a class
CREATE OR REPLACE FUNCTION get_section_counts(p_class_id uuid)
RETURNS TABLE (
  section_id uuid,
  section_code text,
  display_name text,
  current_count bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cs.id as section_id,
    cs.section_code,
    cs.display_name,
    COUNT(v.id) as current_count
  FROM class_sections cs
  LEFT JOIN vbs2025 v ON v.section_id = cs.id
  WHERE cs.class_id = p_class_id
  GROUP BY cs.id, cs.section_code, cs.display_name
  ORDER BY cs.section_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get children in a section
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

-- Function to search children
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_class_counts TO authenticated;
GRANT EXECUTE ON FUNCTION get_section_counts TO authenticated;
GRANT EXECUTE ON FUNCTION get_section_children TO authenticated;
GRANT EXECUTE ON FUNCTION search_children TO authenticated;

COMMIT;