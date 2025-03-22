/*
  # Add acknowledgement_id to vbs2025 table

  1. Changes
    - Add acknowledgement_id column to vbs2025 table
    - Make it unique to prevent duplicates
*/

-- Add acknowledgement_id column to vbs2025 table
ALTER TABLE vbs2025
ADD COLUMN IF NOT EXISTS acknowledgement_id text UNIQUE;

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_vbs2025_acknowledgement_id 
ON vbs2025(acknowledgement_id);