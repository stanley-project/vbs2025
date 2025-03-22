import React from 'react';
import { Link } from 'react-router-dom';
import { Calendar } from 'lucide-react';

export function Home() {
  return (
    <div className="max-w-4xl mx-auto">
      <div className="text-center mb-12">
        <h1 className="text-4xl font-bold text-gray-900 mb-4">
          Welcome to VBS 2025
        </h1>
        <p className="text-lg text-gray-600">
          Join us for an unforgettable summer of fun, learning, and adventure!
        </p>
      </div>

      <div className="bg-white rounded-lg shadow-md p-6 text-center">
        <Link
          to="/register"
          className="inline-block bg-indigo-600 text-white px-8 py-3 rounded-md hover:bg-indigo-700 transition text-lg font-semibold"
        >
          Register Now
        </Link>
      </div>
    </div>
  );
}