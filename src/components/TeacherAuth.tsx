import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useForm } from 'react-hook-form';
import { Loader2, Phone } from 'lucide-react';

type PhoneFormData = {
  phone: string;
};

type OTPFormData = {
  otp: string;
};

export function TeacherAuth() {
  const [step, setStep] = useState<'phone' | 'otp'>('phone');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [phoneNumber, setPhoneNumber] = useState<string>('');
  const navigate = useNavigate();
  
  const phoneForm = useForm<PhoneFormData>();
  const otpForm = useForm<OTPFormData>();

  const handlePhoneSubmit = async (data: PhoneFormData) => {
    try {
      setLoading(true);
      setError(null);
      
      // Format phone number consistently
      const formattedPhone = data.phone.startsWith('+91') 
        ? data.phone 
        : `+91${data.phone}`;
      
      setPhoneNumber(formattedPhone);

      // First check if this is a registered teacher
      const { data: teacherData, error: teacherError } = await supabase
        .from('teachers')
        .select('id, name')
        .eq('phone', formattedPhone);

      if (teacherError) throw teacherError;
      
      if (!teacherData || teacherData.length === 0) {
        throw new Error('Phone number not registered as a teacher. Please contact the administrator.');
      }

      const { data: authData, error: authError } = await supabase.auth.signInWithOtp({
        phone: formattedPhone,
        options: {
          data: {
            role: 'teacher',
            name: teacherData[0].name
          }
        }
      });

      if (authError) throw authError;

      setStep('otp');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  const handleOTPSubmit = async (data: OTPFormData) => {
    try {
      setLoading(true);
      setError(null);

      const { data: verifyData, error } = await supabase.auth.verifyOtp({
        phone: phoneNumber,
        token: data.otp,
        type: 'sms'
      });

      if (error) throw error;

      if (verifyData.session) {
        navigate('/teacher/dashboard');
      } else {
        throw new Error('Failed to verify OTP. Please try again.');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-md mx-auto">
      <div className="bg-white rounded-lg shadow-md p-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">Teacher Login</h2>

        {error && (
          <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-md">
            <p className="text-red-600">{error}</p>
          </div>
        )}

        {step === 'phone' ? (
          <form onSubmit={phoneForm.handleSubmit(handlePhoneSubmit)} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700">
                Phone Number
              </label>
              <div className="mt-1 relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <span className="text-gray-500">+91</span>
                </div>
                <input
                  {...phoneForm.register('phone', {
                    required: true,
                    pattern: {
                      value: /^\d{10}$/,
                      message: "Please enter a valid 10-digit mobile number"
                    }
                  })}
                  type="tel"
                  placeholder="Enter your 10-digit mobile number"
                  className="block w-full pl-12 rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
                {phoneForm.formState.errors.phone && (
                  <span className="text-red-500 text-sm">
                    {phoneForm.formState.errors.phone.message || "Required"}
                  </span>
                )}
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full flex items-center justify-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
            >
              {loading ? (
                <Loader2 className="h-5 w-5 animate-spin" />
              ) : (
                <>
                  <Phone className="h-5 w-5 mr-2" />
                  Send OTP
                </>
              )}
            </button>
          </form>
        ) : (
          <form onSubmit={otpForm.handleSubmit(handleOTPSubmit)} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700">
                Enter OTP
              </label>
              <input
                {...otpForm.register('otp', { 
                  required: true,
                  pattern: {
                    value: /^\d{6}$/,
                    message: "Please enter a valid 6-digit OTP"
                  }
                })}
                type="text"
                placeholder="Enter the 6-digit OTP"
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
              />
              {otpForm.formState.errors.otp && (
                <span className="text-red-500 text-sm">
                  {otpForm.formState.errors.otp.message || "Required"}
                </span>
              )}
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full flex items-center justify-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
            >
              {loading ? (
                <Loader2 className="h-5 w-5 animate-spin" />
              ) : (
                'Verify OTP'
              )}
            </button>

            <button
              type="button"
              onClick={() => {
                setStep('phone');
                setError(null);
              }}
              className="w-full mt-2 text-sm text-indigo-600 hover:text-indigo-500"
            >
              Change phone number
            </button>
          </form>
        )}
      </div>
    </div>
  );
}