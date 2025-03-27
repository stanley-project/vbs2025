/*
  # Add Function to Get Available Sections
  
  1. New Function
    - get_available_sections: Returns sections from same class excluding current section
    
  2. Changes
    - Add class_id to section options
    - Filter sections by class
*/

BEGIN;

-- Function to get available sections for a child
CREATE OR REPLACE FUNCTION get_available_sections(p_child_id uuid)
RETURNS TABLE (
  section_id uuid,
  display_name text,
  class_id uuid,
  current_count bigint,
  max_capacity integer
) AS $$
BEGIN
  RETURN QUERY
  WITH child_class AS (
    SELECT class_id, section_id
    FROM vbs2025
    WHERE id = p_child_id
  )
  SELECT 
    cs.id as section_id,
    cs.display_name,
    cs.class_id,
    COUNT(v.id) as current_count,
    cs.max_capacity
  FROM class_sections cs
  LEFT JOIN vbs2025 v ON v.section_id = cs.id
  WHERE cs.class_id = (SELECT class_id FROM child_class)
    AND cs.id != (SELECT section_id FROM child_class)
  GROUP BY cs.id, cs.display_name, cs.class_id, cs.max_capacity
  ORDER BY cs.display_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_available_sections TO authenticated;

COMMIT;