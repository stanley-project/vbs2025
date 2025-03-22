# VBS Registration System - Technical Design Document

## 1. System Overview

### 1.1 Purpose
The VBS Registration System is a web application designed to manage Vacation Bible School registrations, handle participant data, process payments, and automatically assign children to age-appropriate classes.

### 1.2 Technology Stack
- Frontend: React + TypeScript + Vite
- Styling: Tailwind CSS
- Icons: Lucide React
- Database: Supabase (PostgreSQL)
- Authentication: Supabase Auth
- Form Handling: React Hook Form
- Routing: React Router DOM
- QR Code Generation: qrcode.react

## 2. Database Schema

### 2.1 Core Tables

#### vbs2025 (Current Year Registrations)
```sql
CREATE TABLE vbs2025 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name text NOT NULL,
  last_name text NOT NULL,
  surname text NOT NULL,
  date_of_birth date NOT NULL,
  parent_name text NOT NULL,
  phone_number text NOT NULL,
  payment_method payment_method,
  payment_status payment_status DEFAULT 'pending',
  acknowledgement_id text UNIQUE,
  age integer,
  registration_id uuid REFERENCES registrations(id),
  created_at timestamptz DEFAULT now()
);
```

#### vbs2024 (Previous Year Records)
```sql
CREATE TABLE vbs2024 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name text NOT NULL,
  last_name text NOT NULL,
  date_of_birth date NOT NULL,
  surname text,
  parent_name text NOT NULL,
  phone_number text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  age integer NOT NULL
);
```

#### teachers
```sql
CREATE TABLE teachers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  phone text,
  role text NOT NULL DEFAULT 'teacher' CHECK (role IN ('teacher', 'admin')),
  user_id uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);
```

#### classes
```sql
CREATE TABLE classes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  min_age integer NOT NULL,
  max_age integer NOT NULL,
  max_capacity integer NOT NULL,
  teacher_id uuid REFERENCES teachers(id),
  created_at timestamptz DEFAULT now()
);
```

#### registrations
```sql
CREATE TABLE registrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id uuid REFERENCES vbs2025(id),
  year integer NOT NULL DEFAULT EXTRACT(year FROM CURRENT_DATE),
  payment_status payment_status DEFAULT 'pending',
  payment_amount numeric(10,2) NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(child_id, year)
);
```

#### class_allocations
```sql
CREATE TABLE class_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id uuid REFERENCES registrations(id),
  class_id uuid REFERENCES classes(id),
  created_at timestamptz DEFAULT now(),
  UNIQUE(registration_id, class_id)
);
```

### 2.2 Support Tables

#### acknowledgement_counter
```sql
CREATE TABLE acknowledgement_counter (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  last_used_number integer DEFAULT 99,
  updated_at timestamptz DEFAULT now()
);
```

### 2.3 Custom Types
```sql
CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed');
CREATE TYPE payment_method AS ENUM ('cash', 'upi');
```

## 3. Key Features

### 3.1 Automatic Age Calculation
```sql
CREATE OR REPLACE FUNCTION calculate_age()
RETURNS TRIGGER AS $$
BEGIN
  NEW.age := DATE_PART('year', AGE(NEW.date_of_birth));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_age_on_vbs2025
  BEFORE INSERT OR UPDATE OF date_of_birth
  ON vbs2025
  FOR EACH ROW
  EXECUTE FUNCTION calculate_age();
```

### 3.2 Teacher Authentication
```sql
CREATE OR REPLACE FUNCTION create_auth_user_for_teacher()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Check if user exists
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE phone = NEW.phone
  LIMIT 1;

  IF v_user_id IS NULL THEN
    -- Create new auth user
    INSERT INTO auth.users (
      id, instance_id, phone, role, raw_user_meta_data,
      created_at, updated_at, phone_confirmed_at
    )
    VALUES (
      gen_random_uuid(),
      '00000000-0000-0000-0000-000000000000',
      NEW.phone,
      'authenticated',
      jsonb_build_object('role', NEW.role, 'full_name', NEW.name),
      NOW(), NOW(), NOW()
    )
    RETURNING id INTO v_user_id;
  END IF;

  NEW.user_id := v_user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 3.3 Automatic Class Assignment
```sql
CREATE OR REPLACE FUNCTION allocate_child_to_class()
RETURNS TRIGGER AS $$
DECLARE
  suitable_class_id uuid;
BEGIN
  -- Find suitable class based on age and capacity
  SELECT c.id
  INTO suitable_class_id
  FROM classes c
  LEFT JOIN class_allocations ca ON c.id = ca.class_id
  WHERE EXISTS (
    SELECT 1 FROM vbs2025 v
    WHERE v.id = NEW.child_id
    AND v.age BETWEEN c.min_age AND c.max_age
  )
  GROUP BY c.id, c.max_capacity
  HAVING COUNT(ca.id) < c.max_capacity
  ORDER BY COUNT(ca.id)
  LIMIT 1;

  -- Create allocation if class found
  IF suitable_class_id IS NOT NULL THEN
    INSERT INTO class_allocations (registration_id, class_id)
    VALUES (NEW.id, suitable_class_id);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

## 4. Frontend Components

### 4.1 Core Components
- `App.tsx`: Main application component with routing
- `Navigation.tsx`: Site navigation menu
- `Home.tsx`: Landing page
- `Registration.tsx`: Registration form and process
- `TeacherAuth.tsx`: Teacher authentication
- `TeacherDashboard.tsx`: Teacher's class management

### 4.2 Route Structure
```typescript
<Router>
  <Routes>
    <Route path="/" element={<Home />} />
    <Route path="/register" element={<Registration />} />
    <Route path="/teacher/login" element={<TeacherAuth />} />
    <Route 
      path="/teacher/dashboard" 
      element={
        <ProtectedRoute>
          <TeacherDashboard />
        </ProtectedRoute>
      } 
    />
  </Routes>
</Router>
```

## 5. Security

### 5.1 Row Level Security (RLS)
```sql
-- Teachers can read their own data
CREATE POLICY "Teachers can read their own data"
  ON teachers
  FOR SELECT
  TO authenticated
  USING (
    phone = (current_setting('request.jwt.claims')::json->>'phone')
  );

-- Public can read classes
CREATE POLICY "Public can read classes"
  ON classes FOR SELECT
  TO PUBLIC
  USING (true);

-- Teachers can view their classes
CREATE POLICY "Teachers can view their classes"
  ON classes FOR SELECT
  TO authenticated
  USING (teacher_id = auth.uid());
```

### 5.2 Authentication Flow
1. Teacher enters phone number
2. System sends OTP via SMS
3. Teacher verifies OTP
4. On successful verification:
   - System checks teacher record
   - Updates auth metadata
   - Grants appropriate permissions

## 6. Development Setup

### 6.1 Environment Variables
Required in `.env`:
```
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 6.2 Dependencies
```json
{
  "dependencies": {
    "lucide-react": "^0.344.0",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "@supabase/supabase-js": "^2.39.7",
    "react-router-dom": "^6.22.2",
    "qrcode.react": "^3.1.0",
    "react-hook-form": "^7.51.0",
    "clsx": "^2.1.0",
    "@supabase/auth-ui-react": "^0.4.7",
    "@supabase/auth-ui-shared": "^0.1.8"
  }
}
```

## 7. Deployment

### 7.1 Build Process
```bash
npm run build
```

### 7.2 Database Migrations
Run migrations in order:
1. Base schema
2. Add acknowledgement system
3. Teacher authentication
4. Age calculation
5. Class assignment

## 8. Future Enhancements
1. Attendance tracking
2. Report generation
3. Parent portal
4. Medical information management
5. Payment integration
6. Automated communications