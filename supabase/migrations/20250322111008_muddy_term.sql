/*
  # Fix class allocations table and references
  
  1. Changes
    - Drop old class_allocations table that referenced registrations
    - Create new class_allocations table that references vbs2025 directly
    - Update allocation policies
*/

-- Drop old class_allocations table
DROP TABLE IF EXISTS class_allocations CASCADE;

-- Create new class_allocations table referencing vbs2025
CREATE TABLE IF NOT EXISTS class_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id uuid REFERENCES vbs2025(id),
  class_id uuid REFERENCES classes(id),
  section_id uuid REFERENCES class_sections(id),
  created_at timestamptz DEFAULT now(),
  UNIQUE(child_id, class_id)
);

-- Enable RLS on class_allocations
ALTER TABLE class_allocations ENABLE ROW LEVEL SECURITY;

-- Add policies for class_allocations
CREATE POLICY "Enable insert for system"
  ON class_allocations
  FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "Enable read for public"
  ON class_allocations
  FOR SELECT
  TO public
  USING (true);

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_class_allocations_child_id ON class_allocations(child_id);
CREATE INDEX IF NOT EXISTS idx_class_allocations_class_id ON class_allocations(class_id);
CREATE INDEX IF NOT EXISTS idx_class_allocations_section_id ON class_allocations(section_id);