import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { supabase, checkDuplicateRegistration, generateAcknowledgementId } from '../lib/supabase';
import { Search, Loader2, AlertCircle, UserPlus } from 'lucide-react';

type RegistrationFormData = {
  firstName: string;
  lastName: string;
  surname: string;
  dateOfBirth: string;
  parentName: string;
  phoneNumber: string;
};

type SearchResult = {
  id: string;
  first_name: string;
  last_name: string;
  surname: string;
  parent_name: string;
  date_of_birth: string;
  phone_number: string;
};

export function Registration() {
  const [isReturning, setIsReturning] = useState(false);
  const [isSearching, setIsSearching] = useState(false);
  const [searchName, setSearchName] = useState('');
  const [searchResults, setSearchResults] = useState<SearchResult[]>([]);
  const [foundChild, setFoundChild] = useState<SearchResult | null>(null);
  const [registrationId, setRegistrationId] = useState<string>('');
  const [acknowledgementId, setAcknowledgementId] = useState<string>('');
  const [searchError, setSearchError] = useState<string>('');
  const [paymentStep, setPaymentStep] = useState<'form' | 'payment' | 'complete'>('form');
  const [registrationData, setRegistrationData] = useState<any>(null);
  const [duplicateError, setDuplicateError] = useState<string>('');
  const [paymentMethod, setPaymentMethod] = useState<'cash' | 'upi' | null>(null);
  const [allocationDetails, setAllocationDetails] = useState<any>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [processingError, setProcessingError] = useState<string>('');

  const { register, handleSubmit, reset, formState: { errors } } = useForm<RegistrationFormData>();

  const handleSearch = async () => {
    if (!searchName.trim()) return;

    setIsSearching(true);
    setSearchError('');
    setSearchResults([]);
    try {
      const { data, error } = await supabase
        .from('vbs2024')
        .select('*')
        .ilike('first_name', `%${searchName}%`);

      if (error) throw error;

      if (!data || data.length === 0) {
        setSearchError('No child found with that name. Please try again or register as a new participant.');
        setFoundChild(null);
      } else if (data.length === 1) {
        setFoundChild(data[0]);
        setSearchResults([]);
      } else {
        setSearchResults(data);
        setFoundChild(null);
      }
    } catch (error) {
      console.error('Error searching for child:', error);
      setSearchError('An error occurred while searching. Please try again.');
      setFoundChild(null);
    } finally {
      setIsSearching(false);
    }
  };

  const handleSelectChild = (child: SearchResult) => {
    setFoundChild(child);
    setSearchResults([]);
  };

  // Calculate age from date of birth
  const calculateAge = (dateOfBirth: string) => {
    const today = new Date();
    const birthDate = new Date(dateOfBirth);
    let age = today.getFullYear() - birthDate.getFullYear();
    const monthDiff = today.getMonth() - birthDate.getMonth();
    
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
      age--;
    }
    
    return age;
  };

  // Find appropriate class and section based on age
  const allocateClassAndSection = async (childId: string, dateOfBirth: string) => {
    try {
      const age = calculateAge(dateOfBirth);
      
      // Find the appropriate class based on age
      const { data: classData, error: classError } = await supabase
        .from('classes')
        .select('id, name')
        .lte('min_age', age)
        .gte('max_age', age)
        .single();
      
      if (classError) throw classError;
      
      // Get all sections for this class
      const { data: sectionsData, error: sectionsError } = await supabase
        .from('class_sections')
        .select('id, name, class_id, teacher_id')
        .eq('class_id', classData.id);
      
      if (sectionsError) throw sectionsError;
      
      // For each section, count how many children are already allocated
      const sectionCounts = await Promise.all(
        sectionsData.map(async (section) => {
          const { data, error } = await supabase
            .from('class_allocations')
            .select('id', { count: 'exact' })
            .eq('section_id', section.id);
          
          return {
            sectionId: section.id,
            sectionName: section.name,
            classId: section.class_id,
            teacherId: section.teacher_id,
            count: data?.length || 0
          };
        })
      );
      
      // Sort sections by count (ascending) to find the section with the fewest children
      sectionCounts.sort((a, b) => a.count - b.count);
      
      // Allocate the child to the section with the fewest children
      const targetSection = sectionCounts[0];
      
      // Create the allocation record
      const { error: allocationError } = await supabase
        .from('class_allocations')
        .insert({
          child_id: childId,
          class_id: targetSection.classId,
          section_id: targetSection.sectionId
        });
      
      if (allocationError) throw allocationError;
      
      // Get teacher information for the allocated section
      const { data: teacherData, error: teacherError } = await supabase
        .from('teachers')
        .select('name')
        .eq('id', targetSection.teacherId)
        .single();
      
      if (teacherError) throw teacherError;
      
      return {
        class_name: classData.name,
        section_name: targetSection.sectionName,
        teacher_name: teacherData.name
      };
    } catch (error) {
      console.error("Error allocating class and section:", error);
      throw error;
    }
  };

  const handlePayment = async (method: 'cash' | 'upi') => {
    setIsProcessing(true);
    setProcessingError('');
    try {
      setPaymentMethod(method);
      // Generate acknowledgement ID
      const newAcknowledgementId = await generateAcknowledgementId();
      setAcknowledgementId(newAcknowledgementId);

      // Calculate age and add it to the registration data
      const age = calculateAge(registrationData.date_of_birth);

      // Insert directly into vbs2025 with payment method and acknowledgement ID
      const { data, error } = await supabase
        .from('vbs2025')
        .insert([{
          ...registrationData,
          age: age,
          payment_method: method,
          payment_status: 'completed',
          acknowledgement_id: newAcknowledgementId
        }])
        .select('id, date_of_birth')
        .single();

      if (error) throw error;
      
      setRegistrationId(data.id);

      // Allocate class and section based on age
      const details = await allocateClassAndSection(data.id, data.date_of_birth);
      setAllocationDetails(details);

      setPaymentStep('complete');
    } catch (error) {
      console.error('Error processing payment:', error);
      setProcessingError('An error occurred while processing your registration. Please try again or contact support.');
    } finally {
      setIsProcessing(false);
    }
  };

  const onSubmit = async (data: RegistrationFormData) => {
    try {
      // Check for duplicate registration based on first name and date of birth
      const duplicateId = await checkDuplicateRegistration(
        data.firstName,
        data.dateOfBirth
      );

      if (duplicateId) {
        setDuplicateError(`This child is already registered with Acknowledgement ID: ${duplicateId}`);
        return;
      }

      setRegistrationData({
        first_name: data.firstName,
        last_name: data.lastName,
        surname: data.surname,
        date_of_birth: data.dateOfBirth,
        parent_name: data.parentName,
        phone_number: data.phoneNumber
      });
      setPaymentStep('payment');
    } catch (error) {
      console.error('Error checking duplicate registration:', error);
    }
  };

  if (paymentStep === 'payment') {
    return (
      <div className="max-w-2xl mx-auto bg-white rounded-lg shadow-md p-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">Select Payment Method</h2>
        
        {processingError && (
          <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-md text-red-700">
            <p>{processingError}</p>
          </div>
        )}
        
        <div className="grid grid-cols-2 gap-4">
          <button
            onClick={() => handlePayment('cash')}
            disabled={isProcessing}
            className="p-4 border rounded-lg hover:bg-gray-50 disabled:opacity-50"
          >
            {isProcessing ? 'Processing...' : 'Cash Payment'}
          </button>
          <button
            onClick={() => handlePayment('upi')}
            disabled={isProcessing}
            className="p-4 border rounded-lg hover:bg-gray-50 disabled:opacity-50"
          >
            {isProcessing ? 'Processing...' : 'UPI Payment'}
          </button>
        </div>
      </div>
    );
  }

  if (paymentStep === 'complete') {
    return (
      <div className="max-w-2xl mx-auto bg-white rounded-lg shadow-md p-6 text-center">
        <h2 className="text-2xl font-bold text-gray-900 mb-4">Registration Completed</h2>
        <p className="text-lg mb-4">Your Acknowledgement ID: {acknowledgementId}</p>
        
        {allocationDetails && (
          <div className="mb-6 p-4 bg-gray-50 rounded-lg">
            <h3 className="font-semibold mb-2">Class Assignment Details:</h3>
            <p>Class: {allocationDetails.class_name}</p>
            <p>Section: {allocationDetails.section_name}</p>
            <p>Teacher: {allocationDetails.teacher_name}</p>
          </div>
        )}

        {paymentMethod === 'cash' ? (
          <div>
            <p className="text-lg mb-2">Please pay cash to VBS team in person</p>
            <p className="text-sm text-gray-600">Keep your Acknowledgement ID for reference</p>
          </div>
        ) : (
          <div>
            <p className="mb-4">Please scan the Payment QR code from VBS team to complete payment</p>
            <a 
              href="upi://scan"
              className="inline-block bg-indigo-600 text-white px-4 py-2 rounded-md hover:bg-indigo-700 transition"
            >
              Open UPI App
            </a>
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto bg-white rounded-lg shadow-md p-6">
      <h2 className="text-2xl font-bold text-gray-900 mb-6">VBS 2025 Registration</h2>

      {duplicateError && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-md">
          <p className="text-red-600">{duplicateError}</p>
        </div>
      )}

      <div className="mb-8 space-y-4">
        <div className="flex flex-col md:flex-row gap-4">
          <button
            onClick={() => {
              setIsReturning(false);
              setFoundChild(null);
              setSearchError('');
              setDuplicateError('');
              reset();
            }}
            className={`flex-1 py-4 px-6 rounded-lg flex items-center justify-center gap-2 transition ${
              !isReturning 
                ? 'bg-indigo-600 text-white hover:bg-indigo-700' 
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            <UserPlus className="h-5 w-5" />
            <span>New Registration</span>
          </button>
          <button
            onClick={() => {
              setIsReturning(true);
              setFoundChild(null);
              setSearchError('');
              setDuplicateError('');
              reset();
            }}
            className={`flex-1 py-4 px-6 rounded-lg flex items-center justify-center gap-2 transition ${
              isReturning 
                ? 'bg-indigo-600 text-white hover:bg-indigo-700' 
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            <Search className="h-5 w-5" />
            <span>Find child from VBS 2024</span>
          </button>
        </div>
      </div>

      {isReturning && !foundChild && (
        <div className="mb-6">
          <div className="flex space-x-2">
            <input
              type="text"
              value={searchName}
              onChange={(e) => setSearchName(e.target.value)}
              placeholder="Enter child's first name"
              className="flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
            />
            <button
              onClick={handleSearch}
              disabled={isSearching}
              className="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 transition disabled:opacity-50"
            >
              {isSearching ? (
                <Loader2 className="h-5 w-5 animate-spin" />
              ) : (
                <Search className="h-5 w-5" />
              )}
            </button>
          </div>
          {searchError && (
            <div className="mt-2 flex items-center text-red-600 text-sm">
              <AlertCircle className="h-4 w-4 mr-1" />
              {searchError}
            </div>
          )}

          {searchResults.length > 0 && (
            <div className="mt-4">
              <h3 className="text-lg font-semibold mb-2">Search Results</h3>
              <div className="space-y-2">
                {searchResults.map((child) => (
                  <button
                    key={child.id}
                    onClick={() => handleSelectChild(child)}
                    className="w-full text-left p-3 border rounded-md hover:bg-gray-50 transition"
                  >
                    <div className="font-medium">
                      {child.first_name} {child.last_name} {child.surname}
                    </div>
                    <div className="text-sm text-gray-600">
                      Parent: {child.parent_name}
                    </div>
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {(!isReturning || foundChild) && (
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div className="grid grid-cols-1 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700">Child First Name *</label>
              <input
                {...register('firstName', { required: true })}
                defaultValue={foundChild?.first_name || ''}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
              />
              {errors.firstName && <span className="text-red-500 text-sm">Required</span>}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">Child Last Name *</label>
              <input
                {...register('lastName', { required: true })}
                defaultValue={foundChild?.last_name || ''}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
              />
              {errors.lastName && <span className="text-red-500 text-sm">Required</span>}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">Child Surname (Family Name) *</label>
              <input
                {...register('surname', { required: true })}
                defaultValue={foundChild?.surname || ''}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
              />
              {errors.surname && <span className="text-red-500 text-sm">Required</span>}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">Date of Birth *</label>
              <input
                type="date"
                {...register('dateOfBirth', { required: true })}
                defaultValue={foundChild?.date_of_birth || ''}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
              />
              {errors.dateOfBirth && <span className="text-red-500 text-sm">Required</span>}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">Parent Name *</label>
              <input
                {...register('parentName', { required: true })}
                defaultValue={foundChild?.parent_name || ''}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
              />
              {errors.parentName && <span className="text-red-500 text-sm">Required</span>}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">Phone Number *</label>
              <div className="mt-1 relative">
                <input
                  {...register('phoneNumber', { 
                    required: true,
                    pattern: {
                      value: /^\d{10}$/,
                      message: "Please enter a valid 10-digit mobile number"
                    }
                  })}
                  type="tel"
                  placeholder="Enter 10-digit mobile number"
                  defaultValue={foundChild?.phone_number || ''}
                  className="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
                {errors.phoneNumber && (
                  <span className="text-red-500 text-sm">
                    {errors.phoneNumber.message || "Required"}
                  </span>
                )}
              </div>
            </div>
          </div>

          <button
            type="submit"
            className="w-full px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 transition"
          >
            Submit Registration
          </button>
        </form>
      )}
    </div>
  );
}