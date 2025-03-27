BEGIN;

-- Function to update child's section
CREATE OR REPLACE FUNCTION update_child_section(
  p_child_id uuid,
  p_new_section_id uuid
) RETURNS jsonb AS $$
DECLARE
  v_old_section_id uuid;
  v_old_class_id uuid;
  v_new_class_id uuid;
  v_section_capacity integer;
  v_current_count integer;
BEGIN
  -- Get current section and class
  SELECT section_id, class_id INTO v_old_section_id, v_old_class_id
  FROM vbs2025
  WHERE id = p_child_id;

  -- Get new class_id and check capacity
  SELECT 
    cs.class_id,
    cs.max_capacity,
    COUNT(v.id)::integer as current_count
  INTO v_new_class_id, v_section_capacity, v_current_count
  FROM class_sections cs
  LEFT JOIN vbs2025 v ON v.section_id = cs.id
  WHERE cs.id = p_new_section_id
  GROUP BY cs.id, cs.class_id, cs.max_capacity;

  -- Validate section exists
  IF v_new_class_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Section not found'
    );
  END IF;

  -- Check capacity (don't count if moving within same section)
  IF v_old_section_id != p_new_section_id AND v_current_count >= v_section_capacity THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Section is at maximum capacity'
    );
  END IF;

  -- Update section
  UPDATE vbs2025
  SET 
    section_id = p_new_section_id,
    class_id = v_new_class_id
  WHERE id = p_child_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Section updated successfully'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_child_section TO authenticated;

COMMIT;