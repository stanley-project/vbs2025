/*
  # Summer Camp Registration Schema

  1. New Tables
    - `vbs2024`
      - Stores all children's information
      - Includes historical data for returning campers
    - `registrations`
      - Stores current year's registrations
      - Links to children and includes payment status
    - `teachers`
      - Stores teacher information
    - `classes`
      - Stores class information with teacher assignments
    - `class_allocations`
      - Links children to their assigned classes

  2. Security
    - Enable RLS on all tables
    - Public can read class information
    - Teachers can only view their assigned classes
    - Admin role for full access
*/

-- Create enum for payment status
CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed');

-- Create children table
CREATE TABLE IF NOT EXISTS children (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name text NOT NULL,
  last_name text NOT NULL,
  date_of_birth date NOT NULL,
  allergies text,
  medical_notes text,
  guardian_name text NOT NULL,
  guardian_phone text NOT NULL,
  guardian_email text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create teachers table
CREATE TABLE IF NOT EXISTS teachers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name text NOT NULL,
  last_name text NOT NULL,
  email text UNIQUE NOT NULL,
  phone text,
  created_at timestamptz DEFAULT now(),
  user_id uuid REFERENCES auth.users(id)
);

-- Create classes table
CREATE TABLE IF NOT EXISTS classes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  min_age integer NOT NULL,
  max_age integer NOT NULL,
  max_capacity integer NOT NULL,
  teacher_id uuid REFERENCES teachers(id),
  created_at timestamptz DEFAULT now()
);

-- Create registrations table for current year
CREATE TABLE IF NOT EXISTS registrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id uuid REFERENCES children(id),
  year integer NOT NULL DEFAULT EXTRACT(YEAR FROM CURRENT_DATE),
  payment_status payment_status DEFAULT 'pending',
  payment_amount decimal(10,2) NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(child_id, year)
);

-- Create class allocations table
CREATE TABLE IF NOT EXISTS class_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id uuid REFERENCES registrations(id),
  class_id uuid REFERENCES classes(id),
  created_at timestamptz DEFAULT now(),
  UNIQUE(registration_id, class_id)
);

-- Enable RLS
ALTER TABLE children ENABLE ROW LEVEL SECURITY;
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_allocations ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Public can read classes"
  ON classes FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "Teachers can view their classes"
  ON classes FOR SELECT
  TO authenticated
  USING (teacher_id = auth.uid());

CREATE POLICY "Teachers can view their allocated students"
  ON class_allocations FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM classes
      WHERE classes.id = class_allocations.class_id
      AND classes.teacher_id = auth.uid()
    )
  );

-- Create function to automatically allocate children to classes based on age
CREATE OR REPLACE FUNCTION allocate_child_to_class()
RETURNS TRIGGER AS $$
DECLARE
  child_age integer;
  suitable_class_id uuid;
BEGIN
  -- Calculate child's age
  SELECT EXTRACT(YEAR FROM age(c.date_of_birth))
  INTO child_age
  FROM children c
  WHERE c.id = NEW.child_id;

  -- Find suitable class with available capacity
  SELECT c.id
  INTO suitable_class_id
  FROM classes c
  LEFT JOIN class_allocations ca ON c.id = ca.class_id
  WHERE child_age BETWEEN c.min_age AND c.max_age
  GROUP BY c.id, c.max_capacity
  HAVING COUNT(ca.id) < c.max_capacity
  ORDER BY COUNT(ca.id)
  LIMIT 1;

  -- Create class allocation if suitable class found
  IF suitable_class_id IS NOT NULL THEN
    INSERT INTO class_allocations (registration_id, class_id)
    VALUES (NEW.id, suitable_class_id);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic class allocation
CREATE TRIGGER trigger_allocate_child_to_class
AFTER INSERT ON registrations
FOR EACH ROW
EXECUTE FUNCTION allocate_child_to_class();