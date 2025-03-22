/*
  # Update Teacher Authentication System

  1. Changes
    - Simplify teacher table structure
    - Add automatic auth user creation
    - Update RLS policies
    - Fix trigger conflicts

  2. Security
    - Phone-based authentication
    - Role-based access control
    - Proper metadata handling
*/

-- First, ensure teachers table has the correct structure
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'teachers' AND column_name = 'email') THEN
    ALTER TABLE teachers DROP COLUMN email;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'teachers' AND column_name = 'first_name') THEN
    ALTER TABLE teachers DROP COLUMN first_name;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'teachers' AND column_name = 'last_name') THEN
    ALTER TABLE teachers DROP COLUMN last_name;
  END IF;
END $$;

-- Modify teachers table to match new requirements
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'teachers' AND column_name = 'name') THEN
    ALTER TABLE teachers ADD COLUMN name text NOT NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'teachers' AND column_name = 'phone') THEN
    ALTER TABLE teachers ADD COLUMN phone text;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'teachers' AND column_name = 'role') THEN
    ALTER TABLE teachers ADD COLUMN role text NOT NULL DEFAULT 'teacher';
    ALTER TABLE teachers ADD CONSTRAINT teachers_role_check CHECK (role IN ('teacher', 'admin'));
  END IF;
END $$;

-- Function to create auth user for teacher
CREATE OR REPLACE FUNCTION create_auth_user_for_teacher()
RETURNS TRIGGER AS $$
BEGIN
  -- Only create auth user if phone number exists
  IF NEW.phone IS NOT NULL THEN
    -- Insert into auth.users
    INSERT INTO auth.users (
      phone,
      role,
      raw_user_meta_data
    )
    VALUES (
      NEW.phone,
      'authenticated',
      jsonb_build_object(
        'role', NEW.role,
        'full_name', NEW.name
      )
    )
    RETURNING id INTO NEW.user_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop and recreate trigger for auth user creation
DROP TRIGGER IF EXISTS create_auth_user_after_teacher_insert ON teachers;

CREATE TRIGGER create_auth_user_after_teacher_insert
  BEFORE INSERT ON teachers
  FOR EACH ROW
  EXECUTE FUNCTION create_auth_user_for_teacher();

-- Update RLS policies for teachers
DROP POLICY IF EXISTS "Teachers can read their own data" ON teachers;

CREATE POLICY "Teachers can read their own data"
  ON teachers
  FOR SELECT
  TO authenticated
  USING (
    phone = (current_setting('request.jwt.claims')::json->>'phone')
  );

-- Function to add teacher as authenticated user
CREATE OR REPLACE FUNCTION add_teacher_as_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Update auth.users metadata with teacher role
  UPDATE auth.users
  SET raw_user_meta_data = jsonb_build_object(
    'role', NEW.role,
    'full_name', NEW.name
  )
  WHERE phone = NEW.phone;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop and recreate trigger for updating user metadata
DROP TRIGGER IF EXISTS teachers_after_insert ON teachers;

CREATE TRIGGER teachers_after_insert
  AFTER INSERT ON teachers
  FOR EACH ROW
  EXECUTE FUNCTION add_teacher_as_user();