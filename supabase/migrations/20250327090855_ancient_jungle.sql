/*
  # Add Primary Teacher Support
  
  1. Changes
    - Add is_primary column to section_teachers table
    - Add trigger to handle primary teacher changes
    - Update existing functions to support primary flag
*/

BEGIN;

-- Add is_primary column if it doesn't exist
ALTER TABLE section_teachers
ADD COLUMN IF NOT EXISTS is_primary boolean DEFAULT false;

-- Create function to handle primary teacher changes
CREATE OR REPLACE FUNCTION handle_primary_teacher_change()
RETURNS TRIGGER AS $$
BEGIN
  -- If this is a new primary teacher, unset any existing primary teachers
  IF NEW.is_primary THEN
    UPDATE section_teachers
    SET is_primary = false
    WHERE section_id = NEW.section_id
      AND teacher_id != NEW.teacher_id
      AND is_primary = true;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for primary teacher changes
DROP TRIGGER IF EXISTS trigger_primary_teacher_change ON section_teachers;
CREATE TRIGGER trigger_primary_teacher_change
  BEFORE INSERT OR UPDATE OF is_primary
  ON section_teachers
  FOR EACH ROW
  EXECUTE FUNCTION handle_primary_teacher_change();

COMMIT;