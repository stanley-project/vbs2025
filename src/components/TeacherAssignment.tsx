// src/components/TeacherAssignment.tsx
import React, { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { Loader2, Plus, X, ArrowUpDown } from 'lucide-react';

type TeacherAssignment = {
  teacher_name: string;
  class_section: string;
  student_count: number;
  class_name: string; // Added class name
};

type Teacher = {
  id: string;
  name: string;
};

type Section = {
  id: string;
  display_name: string;
  id: string;
};

type SortField = 'teacher_name' | 'class_section' | 'student_count';

export function TeacherAssignment() {
  const { code } = useParams<{ code: string }>();
  const [assignments, setAssignments] = useState<TeacherAssignment[]>([]);
  const [teachers, setTeachers] = useState<Teacher[]>([]);
  const [sections, setSections] = useState<Section[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showAddForm, setShowAddForm] = useState(false);
  const [selectedTeacher, setSelectedTeacher] = useState('');
  const [selectedSection, setSelectedSection] = useState('');
  const [isPrimary, setIsPrimary] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [sortField, setSortField] = useState<SortField>('teacher_name');
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('asc');

  // Verify admin access
  useEffect(() => {
    if (code !== 'admin2025') {
      window.location.href = '/';
    }
  }, [code]);

  useEffect(() => {
    fetchData();
  }, []);

  const verifyAssignment = async (teacherId: string, sectionId: string) => {
    try {
      const { data: existing, error: existingError } = await supabase
        .from('section_teachers')
        .select('id')
        .eq('teacher_id', teacherId)
        .eq('section_id', sectionId)
        .single();

      if (existingError && existingError.code !== 'PGRST116') {
        console.error('Assignment verification error:', existingError);
        return false;
      }

      return !!existing;
    } catch (err) {
      console.error('Verification error:', err);
      return false;
    }
  };

  const fetchData = async () => {
    try {
      setLoading(true);
      setError(null);

      // Get teacher assignments using the SQL function
      const { data: assignments, error: assignmentError } = await supabase
        .rpc('get_teacher_assignments');

      if (assignmentError) {
        throw new Error(`Failed to fetch assignments: ${assignmentError.message}`);
      }

      // Fetch class name for each assignment
      const assignmentsWithClass = await Promise.all(
        (assignments || []).map(async (assignment) => {
          const sectionName = assignment.class_section;
          const className = sectionName.split('-')[0];
          return {
            ...assignment,
            class_name: className,
          };
        })
      );

      setAssignments(assignmentsWithClass);

      // Fetch available teachers
      const { data: teacherData, error: teacherError } = await supabase
        .from('teachers')
        .select('id, name')
        .order('name');

      if (teacherError) {
        throw new Error(`Failed to fetch teachers: ${teacherError.message}`);
      }
      setTeachers(teacherData || []);

      // Fetch available sections
      const { data: sectionData, error: sectionError } = await supabase
        .from('class_sections')
        .select('id, display_name')
        .order('display_name');

      if (sectionError) {
        throw new Error(`Failed to fetch sections: ${sectionError.message}`);
      }
      console.log('Section Data:', sectionData); // Debug log
      setSections(sectionData || []);

    } catch (err) {
      console.error('Error in fetchData:', err);
      setError(err instanceof Error ? err.message : 'An unexpected error occurred');
    } finally {
      setLoading(false);
    }
  };

  const handleAssignTeacher = async () => {
    if (!selectedTeacher || !selectedSection) {
      setError('Please select both teacher and section');
      return;
    }

    try {
      setIsSubmitting(true);
      setError(null);

      const exists = await verifyAssignment(selectedTeacher, selectedSection);
      
      if (exists) {
        throw new Error('Teacher is already assigned to this section');
      }

      const { error: insertError } = await supabase
        .from('section_teachers')
        .insert({
          teacher_id: selectedTeacher,
          section_id: selectedSection,
          is_primary: isPrimary
        });

      if (insertError) {
        throw new Error(`Failed to assign teacher: ${insertError.message}`);
      }

      setSelectedTeacher('');
      setSelectedSection('');
      setIsPrimary(false);
      setShowAddForm(false);
      await fetchData();

    } catch (err) {
      console.error('Assignment error:', err);
      setError(err instanceof Error ? err.message : 'Failed to assign teacher');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleSort = (field: SortField) => {
    if (sortField === field) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDirection('asc');
    }
  };

  const sortedAssignments = [...assignments].sort((a, b) => {
    // First, sort by class name
    const classComparison = a.class_section.localeCompare(b.class_section);
    if (classComparison !== 0) {
      return classComparison;
    }

    // If class names are the same, sort by section
    return a.class_section.localeCompare(b.class_section);
  });

  const getTotalStudents = (teacherName: string) => {
    return assignments
      .filter(assignment => assignment.teacher_name === teacherName)
      .reduce((total, assignment) => total + assignment.student_count, 0);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <Loader2 className="h-8 w-8 animate-spin text-indigo-600" />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Teacher Assignments</h1>
        <button
          onClick={() => setShowAddForm(true)}
          className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 flex items-center gap-2"
        >
          <Plus className="h-5 w-5" />
          <span>Assign Teacher</span>
        </button>
      </div>

      {error && (
        <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-md">
          <p className="text-red-600">{error}</p>
        </div>
      )}

      {showAddForm && (
        <div className="mb-8 bg-white p-6 rounded-lg shadow-md">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-xl font-semibold">New Assignment</h2>
            <button
              onClick={() => setShowAddForm(false)}
              className="text-gray-500 hover:text-gray-700"
            >
              <X className="h-5 w-5" />
            </button>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Teacher
              </label>
              <select
                value={selectedTeacher}
                onChange={(e) => setSelectedTeacher(e.target.value)}
                className="w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
              >
                <option value="">Select teacher...</option>
                {teachers.map(teacher => (
                  <option key={teacher.id} value={teacher.id}>
                    {teacher.name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Class Section
              </label>
              <select
                value={selectedSection}
                onChange={(e) => setSelectedSection(e.target.value)}
                className="w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
              >
                <option value="">Select section...</option>
                {sections.map(section => (
                  <option key={section.id} value={section.id}>
                    {section.display_name}
                  </option>
                ))}
              </select>
            </div>
          </div>
          <div className="mt-4">
            <label className="flex items-center space-x-2">
              <input
                type="checkbox"
                checked={isPrimary}
                onChange={(e) => setIsPrimary(e.target.checked)}
                className="rounded border-gray-300 text-indigo-600 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
              />
              <span className="text-sm text-gray-700">Set as primary teacher</span>
            </label>
          </div>
          <div className="mt-4 flex justify-end">
            <button
              onClick={handleAssignTeacher}
              disabled={isSubmitting || !selectedTeacher || !selectedSection}
              className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 disabled:opacity-50 flex items-center gap-2"
            >
              {isSubmitting ? (
                <Loader2 className="h-5 w-5 animate-spin" />
              ) : (
                'Assign Teacher'
              )}
            </button>
          </div>
        </div>
      )}

      <div className="bg-white rounded-lg shadow overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th 
                scope="col" 
                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer"
                onClick={() => handleSort('teacher_name')}
              >
                <div className="flex items-center gap-2">
                  Teacher Name
                  <ArrowUpDown className="h-4 w-4" />
                </div>
              </th>
              <th 
                scope="col" 
                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer"
                onClick={() => handleSort('class_section')}
              >
                <div className="flex items-center gap-2">
                  Class Section
                  <ArrowUpDown className="h-4 w-4" />
                </div>
              </th>
              <th 
                scope="col" 
                className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer"
                onClick={() => handleSort('student_count')}
              >
                <div className="flex items-center gap-2">
                  Students
                  <ArrowUpDown className="h-4 w-4" />
                </div>
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {sortedAssignments.length === 0 ? (
              <tr>
                <td colSpan={3} className="px-6 py-4 text-center text-gray-500">
                  No teacher assignments found
                </td>
              </tr>
            ) : (
              sortedAssignments.map((assignment, index) => (
                <tr key={`${assignment.teacher_name}-${assignment.class_section}-${index}`} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    {assignment.teacher_name}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {assignment.class_section}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 text-right">
                    {assignment.student_count}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
        {sortedAssignments.length > 0 && (
          <div className="px-6 py-4 bg-gray-50 text-right">
            <span className="text-sm font-medium text-gray-700">
              Total Students: {getTotalStudents(sortedAssignments[0].teacher_name)}
            </span>
          </div>
        )}
      </div>
    </div>
  );
}
  