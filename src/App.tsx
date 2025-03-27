import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Navigation } from './components/Navigation';
import { Registration } from './components/Registration';
import { Home } from './components/Home';
import { TeacherAuth } from './components/TeacherAuth';
import { TeacherDashboard } from './components/TeacherDashboard';
import { AdminDashboard } from './components/AdminDashboard';
import { TeacherAssignment } from './components/TeacherAssignment';
import { useAuth } from './hooks/useAuth';

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { session } = useAuth();
  
  if (!session) {
    return <Navigate to="/teacher/login" replace />;
  }
  
  return <>{children}</>;
}

function App() {
  return (
    <Router>
      <div className="min-h-screen bg-gray-50">
        <Navigation />
        <main className="container mx-auto px-4 py-8">
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/register" element={<Registration />} />
            <Route path="/teacher/login" element={<TeacherAuth />} />
            <Route 
              path="/teacher/dashboard" 
              element={
                <ProtectedRoute>
                  <TeacherDashboard />
                </ProtectedRoute>
              } 
            />
            <Route path="/admin/:code" element={<AdminDashboard />} />
            <Route path="/admin/:code/teachers" element={<TeacherAssignment />} />
          </Routes>
        </main>
      </div>
    </Router>
  );
}

export default App;