import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { Users } from 'lucide-react';

type Student = {
  id: string;
  first_name: string;
  last_name: string;
  date_of_birth: string;
  allergies: string | null;
  medical_notes: string | null;
  parent_name: string;
  phone_number: string;
};

type Class = {
  id: string;
  name: string;
  min_age: number;
  max_age: number;
  max_capacity: number;
};

export function TeacherDashboard() {
  const [classes, setClasses] = useState<Class[]>([]);
  const [students, setStudents] = useState<{ [key: string]: Student[] }>({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchTeacherClasses() {
      try {
        const { data: teacherClasses, error: classError } = await supabase
          .from('classes')
          .select('*')
          .eq('teacher_id', (await supabase.auth.getUser()).data.user?.id);

        if (classError) throw classError;

        setClasses(teacherClasses || []);

        // Fetch students for each class
        const studentsByClass: { [key: string]: Student[] } = {};
        
        for (const cls of teacherClasses || []) {
          const { data: classStudents, error: studentsError } = await supabase
            .from('class_allocations')
            .select(`
              registrations (
                vbs2024 (*)
              )
            `)
            .eq('class_id', cls.id);

          if (studentsError) throw studentsError;

          studentsByClass[cls.id] = classStudents
            ?.map(allocation => allocation.registrations.vbs2024)
            .filter(Boolean) || [];
        }

        setStudents(studentsByClass);
      } catch (error) {
        console.error('Error fetching teacher data:', error);
      } finally {
        setLoading(false);
      }
    }

    fetchTeacherClasses();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  if (classes.length === 0) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-8">
        <div className="text-center bg-white rounded-lg shadow-md p-8">
          <Users className="h-12 w-12 text-gray-400 mx-auto mb-4" />
          <h2 className="text-2xl font-bold text-gray-900 mb-2">No Classes Assigned</h2>
          <p className="text-gray-600">
            You currently don't have any classes assigned to you. Please contact the administrator.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold text-gray-900 mb-8">Teacher Dashboard</h1>
      
      <div className="grid gap-8">
        {classes.map(cls => (
          <div key={cls.id} className="bg-white rounded-lg shadow-md overflow-hidden">
            <div className="bg-indigo-600 px-6 py-4">
              <h2 className="text-xl font-semibold text-white">{cls.name}</h2>
              <p className="text-indigo-100">
                Ages {cls.min_age}-{cls.max_age} • Maximum {cls.max_capacity} students
              </p>
            </div>

            <div className="p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">
                Enrolled Students ({students[cls.id]?.length || 0}/{cls.max_capacity})
              </h3>

              {students[cls.id]?.length ? (
                <div className="divide-y divide-gray-200">
                  {students[cls.id].map(student => (
                    <div key={student.id} className="py-4">
                      <div className="flex justify-between items-start">
                        <div>
                          <h4 className="text-lg font-medium text-gray-900">
                            {student.first_name} {student.last_name}
                          </h4>
                          <p className="text-sm text-gray-600">
                            Parent: {student.parent_name}
                          </p>
                        </div>
                        <div className="text-right text-sm text-gray-600">
                          <p>Phone: {student.phone_number}</p>
                        </div>
                      </div>
                      
                      {(student.allergies || student.medical_notes) && (
                        <div className="mt-2 text-sm">
                          {student.allergies && (
                            <p className="text-red-600">
                              <strong>Allergies:</strong> {student.allergies}
                            </p>
                          )}
                          {student.medical_notes && (
                            <p className="text-gray-600">
                              <strong>Medical Notes:</strong> {student.medical_notes}
                            </p>
                          )}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-gray-600 text-center py-4">
                  No students enrolled yet.
                </p>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}