/*
  # Improve Registration Process
  
  1. Changes
    - Add API function for child registration
    - Ensure proper transaction handling
    - Add better error handling and validation
    - Maintain trigger functionality
*/

BEGIN;

-- Create API function for child registration
CREATE OR REPLACE FUNCTION api_register_child(
    p_first_name text,
    p_last_name text,
    p_surname text,
    p_date_of_birth date,
    p_parent_name text,
    p_phone_number text,
    p_payment_method payment_method DEFAULT NULL,
    p_payment_status payment_status DEFAULT 'pending'
) RETURNS jsonb AS $$
DECLARE
    v_id uuid;
    v_age integer;
    v_acknowledgement_id text;
    suitable_class_id uuid;
    suitable_section_id uuid;
BEGIN
    -- Calculate age
    v_age := DATE_PART('year', AGE(p_date_of_birth));

    -- Generate acknowledgement ID
    v_acknowledgement_id := generate_next_acknowledgement_id();

    -- Find suitable class based on age
    SELECT c.id
    INTO suitable_class_id
    FROM classes c
    WHERE v_age BETWEEN c.min_age AND c.max_age
    ORDER BY c.min_age
    LIMIT 1;

    -- If suitable class found, find least populated section
    IF suitable_class_id IS NOT NULL THEN
        SELECT cs.id
        INTO suitable_section_id
        FROM class_sections cs
        LEFT JOIN vbs2025 v ON cs.id = v.section_id
        WHERE cs.class_id = suitable_class_id
        GROUP BY cs.id, cs.max_capacity
        HAVING COUNT(v.id) < cs.max_capacity
        ORDER BY COUNT(v.id)
        LIMIT 1;
    END IF;

    -- Insert the record
    INSERT INTO vbs2025 (
        first_name,
        last_name,
        surname,
        date_of_birth,
        parent_name,
        phone_number,
        age,
        payment_method,
        payment_status,
        acknowledgement_id,
        class_id,
        section_id,
        created_at
    ) VALUES (
        p_first_name,
        p_last_name,
        p_surname,
        p_date_of_birth,
        p_parent_name,
        p_phone_number,
        v_age,
        p_payment_method,
        p_payment_status,
        v_acknowledgement_id,
        suitable_class_id,
        suitable_section_id,
        now()
    ) RETURNING id INTO v_id;

    -- Return registration details
    RETURN jsonb_build_object(
        'id', v_id,
        'acknowledgement_id', v_acknowledgement_id
    );

EXCEPTION WHEN OTHERS THEN
    -- Log error details
    RAISE WARNING 'Error in api_register_child: %', SQLERRM;
    RETURN jsonb_build_object(
        'error', SQLERRM,
        'detail', SQLSTATE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated and anon users
GRANT EXECUTE ON FUNCTION api_register_child TO authenticated, anon;

COMMIT;