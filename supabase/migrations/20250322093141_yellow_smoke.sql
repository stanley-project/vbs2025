/*
  # Fix Teacher Authentication Triggers
  
  1. Changes
    - Use CASCADE when dropping functions with dependencies
    - Recreate triggers and functions with proper error handling
    - Update auth user creation logic
*/

-- Drop existing triggers and functions with CASCADE to handle dependencies
DROP TRIGGER IF EXISTS create_auth_user_after_teacher_insert ON teachers CASCADE;
DROP TRIGGER IF EXISTS teachers_after_insert ON teachers CASCADE;
DROP TRIGGER IF EXISTS on_teacher_created ON teachers CASCADE;
DROP FUNCTION IF EXISTS create_auth_user_for_teacher() CASCADE;
DROP FUNCTION IF EXISTS add_teacher_as_user() CASCADE;

-- Function to create auth user for teacher
CREATE OR REPLACE FUNCTION create_auth_user_for_teacher()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Check if user already exists with this phone number
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE phone = NEW.phone
  LIMIT 1;

  IF v_user_id IS NULL THEN
    -- Create new auth user if doesn't exist
    INSERT INTO auth.users (
      id,  -- Explicitly set id
      instance_id,  -- Required by auth.users
      phone,
      role,
      raw_user_meta_data,
      created_at,
      updated_at,
      phone_confirmed_at
    )
    VALUES (
      gen_random_uuid(),  -- Generate new UUID
      '00000000-0000-0000-0000-000000000000',  -- Default instance_id
      NEW.phone,
      'authenticated',
      jsonb_build_object(
        'role', NEW.role,
        'full_name', NEW.name
      ),
      NOW(),
      NOW(),
      NOW()  -- Mark phone as confirmed
    )
    RETURNING id INTO v_user_id;
  ELSE
    -- Update existing user's metadata
    UPDATE auth.users
    SET 
      raw_user_meta_data = jsonb_build_object(
        'role', NEW.role,
        'full_name', NEW.name
      ),
      updated_at = NOW()
    WHERE id = v_user_id;
  END IF;

  -- Set the user_id in teachers table
  NEW.user_id := v_user_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for auth user creation/update
CREATE TRIGGER create_auth_user_after_teacher_insert
  BEFORE INSERT ON teachers
  FOR EACH ROW
  EXECUTE FUNCTION create_auth_user_for_teacher();

-- Update RLS policies
DROP POLICY IF EXISTS "Teachers can read their own data" ON teachers;

CREATE POLICY "Teachers can read their own data"
  ON teachers
  FOR SELECT
  TO authenticated
  USING (
    phone = (current_setting('request.jwt.claims')::json->>'phone')
  );