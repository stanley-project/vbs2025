// src/components/Navigation.tsx
import React from 'react';
import { Link } from 'react-router-dom';
import { Tent } from 'lucide-react';

interface NavigationProps {
  resetForm?: () => void;
}

export function Navigation({ resetForm }: NavigationProps) {
  return (
    <nav className="bg-indigo-600 text-white shadow-lg">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          <Link to="/" className="flex items-center space-x-2">
            <Tent className="h-8 w-8" />
            <span className="text-xl font-bold hidden md:inline">CSI Wesley Church, Secunderabad - VBS 2025</span>
            <span className="text-xl font-bold md:hidden">VBS 2025</span>
          </Link>
          <div className="flex space-x-4">
            <Link to="/register" className="hover:text-indigo-200 transition" onClick={resetForm}>
              Register child
               </Link>
          </div>
        </div>
      </div>
    </nav>
  );
}
