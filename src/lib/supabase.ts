import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Helper function to check for duplicate registrations
export async function checkDuplicateRegistration(firstName: string, dateOfBirth: string) {
  const { data, error } = await supabase
    .from('vbs2025')
    .select('acknowledgement_id')
    .eq('first_name', firstName)
    .eq('date_of_birth', dateOfBirth);

  if (error) throw error;

  // If we have any matches, return the first acknowledgement ID
  if (data && data.length > 0) {
    return data[0].acknowledgement_id;
  }

  return null; // No duplicate found
}

// Generate next acknowledgement ID
export async function generateAcknowledgementId() {
  const { data, error } = await supabase.rpc('generate_next_acknowledgement_id');
  
  if (error) throw error;
  return data;
}