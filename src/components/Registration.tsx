import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { supabase } from '../lib/supabase';
import { Search, Loader2, AlertCircle, UserPlus, QrCode, Coins, ArrowLeft, Calendar } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

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
  const [acknowledgementId, setAcknowledgementId] = useState<string>('');
  const [searchError, setSearchError] = useState<string>('');
  const [paymentStep, setPaymentStep] = useState<'form' | 'payment' | 'complete'>('form');
  const [registrationData, setRegistrationData] = useState<any>(null);
  const [duplicateError, setDuplicateError] = useState<string>('');
  const [paymentMethod, setPaymentMethod] = useState<'cash' | 'upi' | null>(null);
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

  const handlePayment = async (method: 'cash' | 'upi') => {
    setIsProcessing(true);
    setProcessingError('');
    try {
      setPaymentMethod(method);

      const { data, error } = await supabase.rpc('api_register_child', {
        p_first_name: registrationData.first_name,
        p_last_name: registrationData.last_name,
        p_surname: registrationData.surname,
        p_date_of_birth: registrationData.date_of_birth,
        p_parent_name: registrationData.parent_name,
        p_phone_number: registrationData.phone_number,
        p_payment_method: method,
        p_payment_status: 'completed'
      });

      if (error) throw error;

      if (data.error) {
        throw new Error(data.error);
      }

      setAcknowledgementId(data.acknowledgement_id);
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
      setDuplicateError('');
      setProcessingError('');

      const { data: existingData, error: searchError } = await supabase
        .from('vbs2025')
        .select('acknowledgement_id')
        .eq('first_name', data.firstName)
        .eq('date_of_birth', data.dateOfBirth)
        .maybeSingle();

      if (searchError) {
        throw searchError;
      }

      if (existingData?.acknowledgement_id) {
        setDuplicateError(`This child is already registered with Acknowledgement ID: ${existingData.acknowledgement_id}`);
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
      setProcessingError('An error occurred while checking registration. Please try again.');
    }
  };

  const renderForm = () => (
    <motion.form 
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      onSubmit={handleSubmit(onSubmit)} 
      className="space-y-6"
    >
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Child's First Name *</label>
            <input
              {...register('firstName', { required: true })}
              defaultValue={foundChild?.first_name || ''}
              className="w-full px-4 py-2 rounded-lg border border-gray-300 focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all duration-200"
              placeholder="Enter first name"
            />
            {errors.firstName && <span className="text-red-500 text-sm mt-1">Required</span>}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Child's Last Name *</label>
            <input
              {...register('lastName', { required: true })}
              defaultValue={foundChild?.last_name || ''}
              className="w-full px-4 py-2 rounded-lg border border-gray-300 focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all duration-200"
              placeholder="Enter last name"
            />
            {errors.lastName && <span className="text-red-500 text-sm mt-1">Required</span>}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Child's Surname (Family Name) *</label>
            <input
              {...register('surname', { required: true })}
              defaultValue={foundChild?.surname || ''}
              className="w-full px-4 py-2 rounded-lg border border-gray-300 focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all duration-200"
              placeholder="Enter surname"
            />
            {errors.surname && <span className="text-red-500 text-sm mt-1">Required</span>}
          </div>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Date of Birth *</label>
            <div className="relative">
              <input
                type="date"
                {...register('dateOfBirth', { required: true })}
                defaultValue={foundChild?.date_of_birth || ''}
                className="w-full px-4 py-2 rounded-lg border border-gray-300 focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all duration-200"
              />
              <Calendar className="absolute right-3 top-2.5 h-5 w-5 text-gray-400 pointer-events-none" />
            </div>
            {errors.dateOfBirth && <span className="text-red-500 text-sm mt-1">Required</span>}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Parent Name *</label>
            <input
              {...register('parentName', { required: true })}
              defaultValue={foundChild?.parent_name || ''}
              className="w-full px-4 py-2 rounded-lg border border-gray-300 focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all duration-200"
              placeholder="Enter parent's name"
            />
            {errors.parentName && <span className="text-red-500 text-sm mt-1">Required</span>}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Phone Number *</label>
            <div className="relative">
              <span className="absolute left-3 top-2.5 text-gray-500">+91</span>
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
                className="w-full pl-12 pr-4 py-2 rounded-lg border border-gray-300 focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all duration-200"
              />
            </div>
            {errors.phoneNumber && (
              <span className="text-red-500 text-sm mt-1">
                {errors.phoneNumber.message || "Required"}
              </span>
            )}
          </div>
        </div>
      </div>

      <motion.button
        whileHover={{ scale: 1.02 }}
        whileTap={{ scale: 0.98 }}
        type="submit"
        className="w-full px-6 py-3 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-all duration-200 font-medium text-lg shadow-md hover:shadow-lg"
      >
        Submit Registration
      </motion.button>
    </motion.form>
  );

  if (paymentStep === 'payment') {
    return (
      <motion.div 
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0 }}
        className="max-w-2xl mx-auto bg-white rounded-2xl shadow-xl p-8"
      >
        <h2 className="text-2xl font-bold text-gray-900 mb-6">Select Payment Method</h2>
        
        {processingError && (
          <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-xl text-red-700 flex items-start gap-3">
            <AlertCircle className="h-5 w-5 mt-0.5 flex-shrink-0" />
            <p>{processingError}</p>
          </div>
        )}
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => handlePayment('cash')}
            disabled={isProcessing}
            className="p-6 border-2 border-gray-200 rounded-xl hover:border-indigo-500 hover:bg-indigo-50 disabled:opacity-50 transition-all duration-200 flex flex-col items-center justify-center gap-4 group"
          >
            {isProcessing ? (
              <Loader2 className="h-8 w-8 animate-spin text-indigo-600" />
            ) : (
              <>
                <Coins className="h-12 w-12 text-indigo-600 group-hover:scale-110 transition-transform duration-200" />
                <div className="text-center">
                  <span className="block text-lg font-medium text-gray-900 mb-1">Cash Payment</span>
                  <span className="text-sm text-gray-500">Pay in person to VBS team</span>
                </div>
              </>
            )}
          </motion.button>

          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => handlePayment('upi')}
            disabled={isProcessing}
            className="p-6 border-2 border-gray-200 rounded-xl hover:border-indigo-500 hover:bg-indigo-50 disabled:opacity-50 transition-all duration-200 flex flex-col items-center justify-center gap-4 group"
          >
            {isProcessing ? (
              <Loader2 className="h-8 w-8 animate-spin text-indigo-600" />
            ) : (
              <>
                <QrCode className="h-12 w-12 text-indigo-600 group-hover:scale-110 transition-transform duration-200" />
                <div className="text-center">
                  <span className="block text-lg font-medium text-gray-900 mb-1">UPI Payment</span>
                  <span className="text-sm text-gray-500">Scan QR code to pay</span>
                </div>
              </>
            )}
          </motion.button>
        </div>

        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          onClick={() => setPaymentStep('form')}
          className="mt-6 flex items-center gap-2 text-indigo-600 hover:text-indigo-700 transition-colors duration-200"
        >
          <ArrowLeft className="h-4 w-4" />
          <span>Back to registration</span>
        </motion.button>
      </motion.div>
    );
  }

  if (paymentStep === 'complete') {
    return (
      <motion.div 
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0 }}
        className="max-w-2xl mx-auto bg-white rounded-2xl shadow-xl p-8 text-center"
      >
        <motion.div
          initial={{ scale: 0.8, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ delay: 0.2 }}
          className="mb-8"
        >
          <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <motion.svg
              initial={{ pathLength: 0 }}
              animate={{ pathLength: 1 }}
              transition={{ duration: 0.5, delay: 0.5 }}
              className="w-8 h-8 text-green-500"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <motion.path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M5 13l4 4L19 7"
              />
            </motion.svg>
          </div>
          <h2 className="text-2xl font-bold text-gray-900 mb-2">Registration Completed</h2>
          <p className="text-gray-600">Thank you for registering for VBS 2025!</p>
        </motion.div>
        
        <div className="mb-8 p-6 bg-indigo-50 rounded-xl">
          <p className="text-lg font-semibold text-indigo-900 mb-2">
            Your Acknowledgement ID
          </p>
          <p className="text-3xl font-bold text-indigo-600 font-mono">
            {acknowledgementId}
          </p>
        </div>

        {paymentMethod === 'cash' ? (
          <div className="p-6 bg-yellow-50 rounded-xl">
            <h3 className="font-semibold text-yellow-800 mb-3">Cash Payment Instructions</h3>
            <p className="text-yellow-700 mb-4">Please pay cash to VBS team in person</p>
            <p className="text-sm text-yellow-600">
              Keep your Acknowledgement ID for reference
            </p>
          </div>
        ) : (
          <div className="p-6 bg-green-50 rounded-xl">
            <h3 className="font-semibold text-green-800 mb-3">UPI Payment Instructions</h3>
            <p className="text-green-700 mb-6">Please scan the Payment QR code from VBS team to complete payment</p>
            <motion.a 
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              href="upi://scan"
              className="inline-flex items-center gap-2 bg-green-600 text-white px-6 py-3 rounded-lg hover:bg-green-700 transition-colors duration-200 shadow-md"
            >
              <QrCode className="h-5 w-5" />
              <span>Open UPI App</span>
            </motion.a>
          </div>
        )}
      </motion.div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto px-4">
      <motion.div 
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="bg-white rounded-2xl shadow-xl p-8"
      >
        <h2 className="text-2xl md:text-3xl font-bold text-gray-900 mb-8 text-center">VBS 2025 Registration</h2>

        {duplicateError && (
          <motion.div 
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            className="mb-6 p-4 bg-red-50 border border-red-200 rounded-xl"
          >
            <p className="text-red-600 flex items-center gap-2">
              <AlertCircle className="h-5 w-5" />
              {duplicateError}
            </p>
          </motion.div>
        )}

        <div className="mb-8">
          <div className="flex flex-col md:flex-row gap-4">
            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              onClick={() => {
                setIsReturning(false);
                setFoundChild(null);
                setSearchError('');
                setDuplicateError('');
                reset();
              }}
              className={`flex-1 h-12 px-6 rounded-xl flex items-center justify-center gap-3 transition-all duration-200 ${
                !isReturning 
                  ? 'bg-indigo-600 text-white shadow-lg hover:shadow-xl' 
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              <UserPlus className="h-5 w-5" />
              <span className="font-medium">New Registration</span>
            </motion.button>
            
            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              onClick={() => {
                setIsReturning(true);
                setFoundChild(null);
                setSearchError('');
                setDuplicateError('');
                reset();
              }}
              className={`flex-1 h-12 px-6 rounded-xl flex items-center justify-center gap-3 transition-all duration-200 ${
                isReturning 
                  ? 'bg-indigo-600 text-white shadow-lg hover:shadow-xl' 
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              <Search className="h-5 w-5" />
              <span className="font-medium">Find child from VBS 2024</span>
            </motion.button>
          </div>
        </div>

        <AnimatePresence mode="wait">
          {isReturning && !foundChild ? (
            <motion.div
              key="search"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
              className="mb-8"
            >
              <div className="flex items-center gap-3">
                <div className="relative flex-1">
                  <input
                    type="text"
                    value={searchName}
                    onChange={(e) => setSearchName(e.target.value)}
                    placeholder="Enter child's first name"
                    className="w-full h-12 pl-4 pr-10 rounded-xl border border-gray-300 focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all duration-200"
                  />
                </div>
                <motion.button
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  onClick={handleSearch}
                  disabled={isSearching}
                  className="h-12 w-12 flex items-center justify-center bg-indigo-600 text-white rounded-xl hover:bg-indigo-700 transition-all duration-200 disabled:opacity-50 shadow-md hover:shadow-lg"
                >
                  {isSearching ? (
                    <Loader2 className="h-5 w-5 animate-spin" />
                  ) : (
                    <Search className="h-5 w-5" />
                  )}
                </motion.button>
              </div>

              {searchError && (
                <motion.div
                  initial={{ opacity: 0, y: -10 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="mt-3 flex items-center text-red-600 text-sm"
                >
                  <AlertCircle className="h-4 w-4 mr-1" />
                  {searchError}
                </motion.div>
              )}

              <AnimatePresence>
                {searchResults.length > 0 && (
                  <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -20 }}
                    className="mt-6"
                  >
                    <h3 className="text-lg font-semibold mb-3">Search Results</h3>
                    <div className="space-y-3">
                      {searchResults.map((child) => (
                        <motion.button
                          key={child.id}
                          whileHover={{ scale: 1.02 }}
                          whileTap={{ scale: 0.98 }}
                          onClick={() => handleSelectChild(child)}
                          className="w-full text-left p-4 border-2 border-gray-200 rounded-xl hover:border-indigo-500 hover:bg-indigo-50 transition-all duration-200"
                        >
                          <div className="font-medium text-gray-900">
                            {child.first_name} {child.last_name} {child.surname}
                          </div>
                          <div className="text-sm text-gray-600 mt-1">
                            Parent: {child.parent_name}
                          </div>
                        </motion.button>
                      ))}
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </motion.div>
          ) : (
            renderForm()
          )}
        </AnimatePresence>
      </motion.div>
    </div>
  );
}