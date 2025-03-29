import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { Users, Search, ChevronDown, UserPlus, ArrowUp, ArrowDown, AlertCircle, Loader2 } from 'lucide-react';

// Define types
type TeacherAssignment = {
  teacher_name: string;
  class_section: string;
  student_count: number;
  is_primary: boolean;
};

type Teacher = {
  id: string;
  name: string;
};

type Section = {
  id: string;
  class_id: string;
  section_code: string;
  display_name: string | null;
};

type SortField = 'teacher_name' | 'class_section' | 'student_count';

export function TeacherAssignment() {
  const { code } = useParams<{ code: string }>();
  const [assignments, setAssignments] = useState<TeacherAssignment[]>([]);
  const [teachers, setTeachers] = useState<Teacher[]>([]);
  const [sections, setSections] = useState<Section[]>([]);
  const [loading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showAddForm, setShowAddForm] = useState(false);
  const [selectedTeacher, setSelectedTeacher] = useState('');
  const [selectedSection, setSelectedSection] = useState('');
  const [isPrimary, setIsPrimary] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [sortField, setSortField] = useState<SortField>('teacher_name');
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('asc');
  const [submitStatus, setSubmitStatus] = useState<{
    type: 'success' | 'error';
    message: string;
  } | null>(null);
  const [debugInfo, setDebugInfo] = useState<any>(null);

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
      setIsLoading(true);
      setError(null);

      // Fetch assignments
      const { data: assignments, error: assignmentError } = await supabase
        .rpc('get_teacher_assignments');

      if (assignmentError) {
        throw new Error(`Failed to fetch assignments: ${assignmentError.message}`);
      }
      setAssignments(assignments || []);

      // Fetch teachers
      const { data: teacherData, error: teacherError } = await supabase
        .from('teachers')
        .select('id, name')
        .order('name');

      if (teacherError) {
        throw new Error(`Failed to fetch teachers: ${teacherError.message}`);
      }
      setTeachers(teacherData || []);

      // Fetch sections with debug logging
      const { data: sectionData, error: sectionError } = await supabase
        .from('class_sections')
        .select(`
          id,
          name,
          section_code,
          display_name,
          class_id,
          classes (
            name
          )
        `)
        .order('display_name');

      if (sectionError) {
        throw new Error(`Failed to fetch sections: ${sectionError.message}`);
      }

      // Log section data for debugging
      console.log('Raw section data:', sectionData);

      if (!sectionData || sectionData.length === 0) {
        setDebugInfo({ message: 'No sections found in database' });
        setSections([]);
        return;
      }

      const transformedSections = sectionData.map(section => {
        const displayName = section.display_name || 
          `${section.classes?.name || section.name} - ${section.section_code}`;
        
        return {
          id: section.id,
          class_id: section.class_id,
          section_code: section.section_code,
          display_name: displayName
        };
      });

      console.log('Transformed sections:', transformedSections);
      setSections(transformedSections);

    } catch (err) {
      console.error('Error in fetchData:', err);
      setError(err instanceof Error ? err.message : 'An unexpected error occurred');
      setDebugInfo(err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleAssignTeacher = async () => {
    if (!selectedTeacher || !selectedSection) {
      setSubmitStatus({
        type: 'error',
        message: 'Please select both teacher and section'
      });
      return;
    }

    try {
      setIsSubmitting(true);
      setError(null);
      setSubmitStatus(null);

      const exists = await verifyAssignment(selectedTeacher, selectedSection);

      if (exists) {
        setSubmitStatus({
          type: 'error',
          message: 'Teacher is already assigned to this section'
        });
        return;
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

      setSubmitStatus({
        type: 'success',
        message: 'Teacher assigned successfully'
      });

      setSelectedTeacher('');
      setSelectedSection('');
      setIsPrimary(false);
      setShowAddForm(false);
      await fetchData();

    } catch (err) {
      console.error('Assignment error:', err);
      setSubmitStatus({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to assign teacher'
      });
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

  const getSortedAssignments = () => {
    return [...assignments].sort((a, b) => {
      const multiplier = sortDirection === 'asc' ? 1 : -1;

      switch (sortField) {
        case 'teacher_name':
          return multiplier * a.teacher_name.localeCompare(b.teacher_name);
        case 'class_section':
          return multiplier * a.class_section.localeCompare(b.class_section);
        case 'student_count':
          return multiplier * (a.student_count - b.student_count);
        default:
          return 0;
      }
    });
  };

  const getTotalStudents = () => {
    return assignments.reduce((total, assignment) => total + assignment.student_count, 0);
  };

  const renderSortIcon = (field: SortField) => {
    if (sortField !== field) {
      return <ChevronDown className="h-4 w-4 text-gray-400" />;
    }
    return sortDirection === 'asc' ?
      <ArrowUp className="h-4 w-4 text-indigo-600" /> :
      <ArrowDown className="h-4 w-4 text-indigo-600" />;
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  const sortedAssignments = getSortedAssignments();

  return (
    <div className="max-w-7xl mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Teacher Assignments</h1>
        <button
          onClick={() => setShowAddForm(true)}
          className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 flex items-center gap-2"
        >
          <UserPlus className="h-5 w-5" />
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
              onClick={() => {
                setShowAddForm(false);
                setSubmitStatus(null);
              }}
              className="text-gray-500 hover:text-gray-700"
            >
              ×
            </button>
          </div>

          {submitStatus && (
            <div className={`mb-4 p-4 rounded-md ${
              submitStatus.type === 'success' 
                ? 'bg-green-50 border border-green-200 text-green-700' 
                : 'bg-red-50 border border-red-200 text-red-700'
            }`}>
              <div className="flex items-center gap-2">
                {submitStatus.type === 'error' && <AlertCircle className="h-5 w-5" />}
                <p>{submitStatus.message}</p>
              </div>
            </div>
          )}

          {/* Debug Info */}
          {debugInfo && (
            <div className="mb-4 p-4 bg-yellow-50 border border-yellow-200 rounded-md">
              <p className="text-yellow-800 font-mono text-sm">
                Debug Info: {JSON.stringify(debugInfo, null, 2)}
              </p>
            </div>
          )}

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Teacher
              </label>
              <select
                value={selectedTeacher}
                onChange={(e) => setSelectedTeacher(e.target.value)}
                className="w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                disabled={isSubmitting}
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
                disabled={isSubmitting}
              >
                <option value="">Select class-section...</option>
                {sections.map(section => (
                  <option key={section.id} value={section.id}>
                    {section.display_name}
                  </option>
                ))}
              </select>
              {sections.length === 0 && (
                <p className="mt-1 text-sm text-red-600">No sections available</p>
              )}
            </div>
          </div>
          <div className="mt-4">
            <label className="flex items-center space-x-2">
              <input
                type="checkbox"
                checked={isPrimary}
                onChange={(e) => setIsPrimary(e.target.checked)}
                className="rounded border-gray-300 text-indigo-600 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                disabled={isSubmitting}
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
                <>
                  <Loader2 className="h-5 w-5 animate-spin" />
                  <span>Assigning...</span>
                </>
              ) : (
                <>
                  <UserPlus className="h-5 w-5" />
                  <span>Assign Teacher</span>
                </>
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
                  {renderSortIcon('teacher_name')}
                </div>
              </th>
              <th
                scope="col"
                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer"
                onClick={() => handleSort('class_section')}
              >
                <div className="flex items-center gap-2">
                  Class Section
                  {renderSortIcon('class_section')}
                </div>
              </th>
              <th
                scope="col"
                className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer"
                onClick={() => handleSort('student_count')}
              >
                <div className="flex items-center justify-end gap-2">
                  Students
                  {renderSortIcon('student_count')}
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
                    {assignment.is_primary && (
                      <span className="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
                        Primary
                      </span>
                    )}
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
          {sortedAssignments.length > 0 && (
            <tfoot className="bg-gray-50">
              <tr>
                <td colSpan={2} className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 text-right">
                  Total Students:
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 text-right">
                  {getTotalStudents()}
                </td>
              </tr>
            </tfoot>
          )}
        </table>
      </div>
    </div>
  );
}
