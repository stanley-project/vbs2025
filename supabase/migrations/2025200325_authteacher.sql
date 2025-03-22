-- Create new migration file: supabase/migrations/YYYYMMDDHHMMSS_teacher_auth_trigger.sql

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
        'full_name', NEW.first_name || ' ' || NEW.last_name
      )
    )
    RETURNING id INTO NEW.user_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to run function on teacher insert
CREATE OR REPLACE TRIGGER create_auth_user_after_teacher_insert
  BEFORE INSERT ON teachers
  FOR EACH ROW
  EXECUTE FUNCTION create_auth_user_for_teacher();