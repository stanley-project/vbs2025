import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { Users, Search, ChevronDown, UserPlus } from 'lucide-react';

type ClassCount = {
  class_id: string;
  class_name: string;
  total_count: number;
  sections: {
    section_id: string;
    section_code: string;
    display_name: string;
    current_count: number;
  }[];
};

type ChildDetails = {
  child_id: string;
  full_name: string;
  parent_name: string;
  class_section: string;
  teacher_name: string | null;
};

type SectionOption = {
  section_id: string;
  display_name: string;
  current_count: number;
  max_capacity: number;
};

export function AdminDashboard() {
  const { code } = useParams<{ code: string }>();
  const [classCounts, setClassCounts] = useState<ClassCount[]>([]);
  const [selectedClass, setSelectedClass] = useState<string | null>(null);
  const [selectedSection, setSelectedSection] = useState<string | null>(null);
  const [sectionChildren, setSectionChildren] = useState<ChildDetails[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState<ChildDetails[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [availableSections, setAvailableSections] = useState<SectionOption[]>([]);
  const [selectedChild, setSelectedChild] = useState<string | null>(null);
  const [newSectionId, setNewSectionId] = useState<string>('');
  const [isUpdating, setIsUpdating] = useState(false);

  // Verify admin access
  useEffect(() => {
    if (code !== 'admin2025') {
      window.location.href = '/';
    }
  }, [code]);

  // Fetch available sections when a child is selected
  useEffect(() => {
    const fetchAvailableSections = async () => {
      if (!selectedChild) {
        setAvailableSections([]);
        return;
      }

      try {
        const { data, error } = await supabase
          .rpc('get_available_sections', { p_child_id: selectedChild });

        if (error) throw error;
        setAvailableSections(data || []);
      } catch (err) {
        console.error('Error fetching available sections:', err);
        setError('Failed to load available sections');
      }
    };

    fetchAvailableSections();
  }, [selectedChild]);

  // Fetch class counts
  useEffect(() => {
    const fetchClassCounts = async () => {
      try {
        setIsLoading(true);
        setError(null);

        const { data: classes, error: classError } = await supabase
          .rpc('get_class_counts');

        if (classError) throw classError;

        const classesWithSections = await Promise.all((classes || []).map(async (cls) => {
          const { data: sections, error: sectionError } = await supabase
            .rpc('get_section_counts', { p_class_id: cls.class_id });

          if (sectionError) throw sectionError;

          return {
            ...cls,
            sections: sections || []
          };
        }));

        setClassCounts(classesWithSections);
      } catch (err) {
        console.error('Error fetching class counts:', err);
        setError('Failed to load class data');
      } finally {
        setIsLoading(false);
      }
    };

    fetchClassCounts();
  }, []);

  const handleClassClick = (className: string) => {
    setSelectedClass(selectedClass === className ? null : className);
    setSelectedSection(null);
    setSectionChildren([]);
  };

  const handleSectionClick = async (sectionId: string) => {
    try {
      setIsLoading(true);
      setError(null);

      if (selectedSection === sectionId) {
        setSelectedSection(null);
        setSectionChildren([]);
        return;
      }

      setSelectedSection(sectionId);

      const { data, error } = await supabase
        .rpc('get_section_children', { p_section_id: sectionId });

      if (error) throw error;

      setSectionChildren(data || []);
    } catch (err) {
      console.error('Error fetching section children:', err);
      setError('Failed to load section data');
    } finally {
      setIsLoading(false);
    }
  };

  const handleSearch = async () => {
    if (!searchTerm.trim()) return;

    try {
      setIsSearching(true);
      setError(null);

      const { data, error } = await supabase
        .rpc('search_children', { p_search_term: searchTerm });

      if (error) throw error;

      setSearchResults(data || []);
    } catch (err) {
      console.error('Search error:', err);
      setError('Search failed. Please try again.');
    } finally {
      setIsSearching(false);
    }
  };

  const handleUpdateSection = async (childId: string, newSectionId: string) => {
    try {
      setIsUpdating(true);
      setError(null);

      const { data, error } = await supabase
        .rpc('update_child_section', {
          p_child_id: childId,
          p_new_section_id: newSectionId
        });

      if (error) throw error;

      if (!data.success) {
        throw new Error(data.error);
      }

      // Refresh data
      if (selectedSection) {
        handleSectionClick(selectedSection);
      }
      if (searchTerm) {
        handleSearch();
      }

      setSelectedChild(null);
      setNewSectionId('');
    } catch (err) {
      console.error('Error updating section:', err);
      setError(err instanceof Error ? err.message : 'Failed to update section');
    } finally {
      setIsUpdating(false);
    }
  };

  const renderChildRow = (child: ChildDetails) => (
    <tr key={child.child_id} className="hover:bg-gray-50">
      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
        {child.full_name}
      </td>
      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
        {child.parent_name}
      </td>
      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
        {selectedChild === child.child_id ? (
          <div className="flex items-center gap-2">
            <select
              value={newSectionId}
              onChange={(e) => setNewSectionId(e.target.value)}
              className="rounded border-gray-300 text-sm"
              disabled={isUpdating}
            >
              <option value="">Select section...</option>
              {availableSections.map(section => (
                <option 
                  key={section.section_id} 
                  value={section.section_id}
                  disabled={section.current_count >= section.max_capacity}
                >
                  {section.display_name} ({section.current_count}/{section.max_capacity})
                </option>
              ))}
            </select>
            <button
              onClick={() => handleUpdateSection(child.child_id, newSectionId)}
              disabled={!newSectionId || isUpdating}
              className="px-2 py-1 text-xs bg-indigo-600 text-white rounded hover:bg-indigo-700 disabled:opacity-50"
            >
              {isUpdating ? 'Updating...' : 'Update'}
            </button>
            <button
              onClick={() => {
                setSelectedChild(null);
                setNewSectionId('');
              }}
              className="px-2 py-1 text-xs bg-gray-200 text-gray-700 rounded hover:bg-gray-300"
            >
              Cancel
            </button>
          </div>
        ) : (
          <div className="flex items-center gap-2">
            <span>{child.class_section}</span>
            <button
              onClick={() => setSelectedChild(child.child_id)}
              className="px-2 py-1 text-xs bg-gray-100 text-gray-700 rounded hover:bg-gray-200"
            >
              Change
            </button>
          </div>
        )}
      </td>
      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
        {child.teacher_name || 'Unassigned'}
      </td>
    </tr>
  );

  if (isLoading && classCounts.length === 0) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
        <Link
          to={`/admin/${code}/teachers`}
          className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 flex items-center gap-2"
        >
          <UserPlus className="h-5 w-5" />
          <span>Teacher Assignment</span>
        </Link>
      </div>

      {error && (
        <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-md">
          <p className="text-red-600">{error}</p>
        </div>
      )}

      {/* Search Section */}
      <div className="mb-12 bg-white rounded-lg shadow-md p-6">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">Search Children</h2>
        <div className="flex gap-4 mb-6">
          <div className="flex-1 relative">
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search by name or class-section (e.g., BEGINNERS-A)"
              className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-indigo-500"
              list="class-options"
            />
            <datalist id="class-options">
              {classCounts.map(cls => 
                cls.sections.map(section => (
                  <option key={section.section_id} value={section.display_name} />
                ))
              )}
            </datalist>
          </div>
          <button
            onClick={handleSearch}
            disabled={isSearching || !searchTerm.trim()}
            className="px-6 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 disabled:opacity-50"
          >
            {isSearching ? 'Searching...' : 'Search'}
          </button>
        </div>

        {searchResults.length > 0 && (
          <div className="mt-4">
            <h3 className="text-lg font-medium text-gray-900 mb-4">
              Search Results ({searchResults.length})
            </h3>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Child Name
                    </th>
                    <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Parent Name
                    </th>
                    <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Class-Section
                    </th>
                    <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Teacher Name
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {searchResults.map(child => renderChildRow(child))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>

      {/* Dashboard Section */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {classCounts.map(classData => (
          <div key={classData.class_id} className="space-y-4">
            <button
              onClick={() => handleClassClick(classData.class_name)}
              className="w-full bg-white rounded-lg shadow-md p-6 text-left hover:bg-gray-50 transition"
            >
              <div className="flex justify-between items-center">
                <h3 className="text-lg font-semibold text-gray-900">{classData.class_name}</h3>
                <ChevronDown 
                  className={`h-5 w-5 text-gray-500 transition-transform ${
                    selectedClass === classData.class_name ? 'transform rotate-180' : ''
                  }`}
                />
              </div>
              <p className="text-3xl font-bold text-indigo-600 mt-2">{classData.total_count}</p>
              <p className="text-sm text-gray-600">Total Count</p>
            </button>

            {selectedClass === classData.class_name && (
              <div className="space-y-2">
                {classData.sections.map(section => (
                  <div key={section.section_id}>
                    <button
                      onClick={() => handleSectionClick(section.section_id)}
                      className="w-full bg-indigo-50 rounded-lg p-4 text-left hover:bg-indigo-100 transition"
                    >
                      <div className="flex justify-between items-center">
                        <h4 className="font-medium text-indigo-900">
                          {section.display_name}
                        </h4>
                        <span className="text-indigo-600 font-semibold">{section.current_count}</span>
                      </div>
                    </button>

                    {selectedSection === section.section_id && sectionChildren.length > 0 && (
                      <div className="mt-2 bg-white rounded-lg shadow p-4">
                        <table className="min-w-full divide-y divide-gray-200">
                          <thead className="bg-gray-50">
                            <tr>
                              <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Child Name
                              </th>
                              <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Parent Name
                              </th>
                              <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Class-Section
                              </th>
                              <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Teacher Name
                              </th>
                            </tr>
                          </thead>
                          <tbody className="bg-white divide-y divide-gray-200">
                            {sectionChildren.map(child => renderChildRow(child))}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}