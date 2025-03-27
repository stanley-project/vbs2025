-- Create or replace the count_students_by_section function

CREATE OR REPLACE FUNCTION public.count_students_by_section()
RETURNS TABLE(section_id uuid, student_count bigint)
LANGUAGE sql
AS $$
SELECT section_id, COUNT(id) as student_count
FROM vbs2025
WHERE section_id IS NOT NULL
GROUP BY section_id;
$$;