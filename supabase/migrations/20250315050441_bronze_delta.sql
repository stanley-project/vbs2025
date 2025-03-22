/*
  # Rename children table to vbs2024

  1. Changes
    - Rename children table to vbs2024
    - Update foreign key references
    - Update RLS policies
*/

-- Rename children table to vbs2024
ALTER TABLE IF EXISTS children RENAME TO vbs2024;

-- Update foreign key references in registrations table
ALTER TABLE registrations 
  RENAME CONSTRAINT registrations_child_id_fkey TO registrations_child_id_vbs2024_fkey;

-- Update RLS policies
DROP POLICY IF EXISTS "Enable read access for all users" ON vbs2024;
CREATE POLICY "Enable read access for all users"
  ON vbs2024 FOR SELECT
  TO public
  USING (true);