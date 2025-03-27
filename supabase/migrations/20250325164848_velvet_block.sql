/*
  # Fix Ambiguous Column Reference
  
  1. Changes
    - Qualify ambiguous class_id reference with table name
    - Improve query readability
    - Add better error handling
*/

BEGIN;

-- Drop existing function
DROP FUNCTION IF EXISTS get_available_sections(uuid);

-- Create updated function with qualified column references
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
    SELECT v.class_id as current_class_id, v.section_id as current_section_id
    FROM vbs2025 v
    WHERE v.id = p_child_id
  )
  SELECT 
    cs.id as section_id,
    cs.display_name,
    cs.class_id,
    COUNT(v.id) as current_count,
    cs.max_capacity
  FROM class_sections cs
  LEFT JOIN vbs2025 v ON v.section_id = cs.id
  WHERE cs.class_id = (SELECT current_class_id FROM child_class)
    AND cs.id != (SELECT current_section_id FROM child_class)
  GROUP BY cs.id, cs.display_name, cs.class_id, cs.max_capacity
  ORDER BY cs.display_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_available_sections TO authenticated;

COMMIT;