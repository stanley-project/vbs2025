
Product Requirements Document (PRD)
VBS Registration System

1. Introduction
1.1 Purpose
The VBS Registration System is a web application designed to streamline the registration process for Vacation Bible School 2025. The system allows parents to register their children, handles returning participant data retrieval, processes payments, and automatically assigns children to appropriate classes based on age.
1.2 Scope
This document outlines the functional requirements, user flows, system architecture, and implementation details for the VBS Registration System.
1.3 Technology Stack
•	Frontend: React, TypeScript, Tailwind CSS, React Router DOM
•	Backend/Database: Supabase
•	Deployment: Netlify
•	Development Environment: Vite
2. System Overview
2.1 System Architecture
The VBS Registration System follows a client-server architecture:
•	Client-side: React application handling UI rendering and user interactions
•	Server-side: Supabase handling data storage, retrieval, and authentication
•	Database: Supabase PostgreSQL database storing participant information, classes, teachers, and registrations
2.2 Database Schema
The database consists of the following tables:
1.	vbs2024 (Previous year's registrations)
o	id (uuid, primary key)
o	first_name (text)
o	last_name (text)
o	surname (text)
o	date_of_birth (date)
o	parent_name (text)
o	phone_number (text)
o	created_at (timestamptz)
o	updated_at (timestamptz)
o	age (int4)
2.	vbs2025 (Current year's registrations)
o	id (uuid, primary key)
o	acknowledgement_id (text, unique)
o	first_name (text)
o	last_name (text)
o	surname (text)
o	date_of_birth (date)
o	parent_name (text)
o	phone_number (text)
o	payment_method (payment_method)
o	payment_status (payment_status)
o	created_at (timestamptz)
3.	registrations (Link between registration and payment)
o	id (uuid, primary key)
o	child_id (uuid, foreign key to vbs2025.id)
o	year (int4)
o	payment_status (payment_status)
o	payment_amount (numeric)
o	created_at (timestamptz)
o	updated_at (timestamptz)
4.	classes (Available classes)
o	id (uuid, primary key)
o	name (text)
o	min_age (int4)
o	max_age (int4)
o	max_capacity (int4)
o	created_at (timestamptz)
5.	class_sections (Sections within each class)
o	id (uuid, primary key)
o	class_id (uuid, foreign key to classes.id)
o	name (text)
o	teacher_id (uuid, foreign key to teachers.id)
o	max_capacity (int4)
o	created_at (timestamptz)
6.	teachers (Teacher information)
o	id (uuid, primary key)
o	name (text)
o	phone (text)
o	created_at (timestamptz)
o	user_id (uuid, foreign key to auth.users)
7.	class_allocations (Assignments of children to class sections)
o	id (uuid, primary key)
o	registration_id (uuid, foreign key to registrations.id)
o	class_id (uuid, foreign key to classes.id)
o	section_id (uuid, foreign key to class_sections.id)
o	created_at (timestamptz)
8.	users (System users)
o	id (uuid, primary key)
o	phone (text)
o	role (enum: 'admin', 'teacher')
o	created_at (timestamptz)
9.	acknowledgement_counter (For tracking sequential IDs)
o	id (uuid, primary key)
o	last_used_number (integer)
o	updated_at (timestamptz)
3. User Roles and Permissions
3.1 Anonymous Users / Parents
•	View the homepage
•	Register new children
•	Search for returning children
•	Complete registration process
•	Make payments
3.2 Teachers
•	Access their dashboard (protected route)
•	View their assigned classes and sections
•	View student information for their classes
•	View medical notes and allergies for their students
•	Take attendance (future enhancement)
•	Cannot move students between sections (admin only)
3.3 Administrators
•	Access admin dashboard (protected route)
•	Create, edit, and delete classes
•	Create, edit, and delete class sections
•	Assign and reassign teachers to sections
•	View all registrations and payment statuses
•	View class and section enrollment statistics
•	Move children between sections
•	Generate reports
•	Manage teacher accounts
4. Functional Requirements
4.1 Homepage
•	Display welcome message
•	Provide clear call-to-action button for registration
•	Include navigation to other sections
•	Display VBS branding and theme elements
4.2 Registration Process
1.	Initial Step:
o	Option to register as new participant
o	Option to identify as returning participant
2.	Returning Participant Flow:
o	Search for child using first name
o	Display search results if multiple matches
o	Select the correct child from results
o	Pre-fill registration form with existing data
o	Allow modification of pre-filled data
3.	New Participant Flow:
o	Complete registration form with all required fields
4.	Required Registration Information:
o	Child's first name
o	Child's last name
o	Child's surname (family name)
o	Date of birth
o	Parent's name
o	Contact phone number (10-digit)
5.	Form Validation:
o	All required fields must be completed
o	Phone number must follow valid format (10 digits)
o	Date of birth must be valid
6.	Duplicate Registration Prevention:
o	Check for existing registrations with matching child name (first_name + last_name) and parent name
o	If duplicate is found, display message: "Child is already registered with Acknowledgement ID: [ID]"
o	Prevent submission of duplicate registrations
7.	Acknowledgement ID Generation:
o	Generate a 7-digit sequential numeric Acknowledgement ID starting with 2025100
o	Store the Acknowledgement ID with the registration record
o	Display the Acknowledgement ID to the user upon successful registration
o	Example IDs: 2025100, 2025101, 2025102, etc.
4.3 Payment Processing
1.	Payment Methods:
o	Cash payment option
o	UPI payment option
2.	Cash Payment Flow:
o	Selection of cash payment method
o	Display confirmation message to pay VBS team in person
o	Display registration Acknowledgement ID
3.	UPI Payment Flow:
o	Selection of UPI payment method
o	Display QR code for payment
o	Provide payment status confirmation
o	Display registration Acknowledgement ID
4.4 Class Assignment
1.	Automatic Class Assignment Logic:
o	Assign children to appropriate class based on age
o	Balance enrollment across multiple sections of same class
o	Respect maximum capacity limits per section
2.	Class Structure:
o	Classes defined by age range (min_age, max_age)
o	Each class has multiple sections
o	Each section has an assigned teacher
o	Each section has a maximum capacity
4.5 Teacher Dashboard
1.	Teacher View:
o	Display sections assigned to the logged-in teacher
o	Show student count per section
o	Display student details including: 
	Full name
	Parent name
	Contact information
	Medical notes and allergies
	Acknowledgement ID
o	Option to mark attendance (future enhancement)
o	Print class roster
2.	Access Control:
o	Teachers can only view their assigned sections
o	Teachers cannot modify student information
o	Teachers cannot move students between sections
4.6 Admin Dashboard
1.	Authentication:
o	Secure login for administrators
o	Role-based access control
2.	Class Management:
o	View all classes and sections
o	Create new classes with age ranges
o	Edit existing class details
o	Create, edit, and delete class sections
o	Assign teachers to sections
3.	Registration Management:
o	View all registrations with Acknowledgement IDs
o	Filter registrations by class, section, payment status
o	Search for specific children or by Acknowledgement ID
o	Edit registration information
o	View and update payment status
4.	Section Management:
o	View enrollment counts by class and section
o	View distribution of students across sections
o	Move children between sections
o	Balance sections manually
5.	Reporting:
o	Generate enrollment reports by class/section
o	Export registration data
o	Payment status reports
o	Age distribution reports
5. Non-Functional Requirements
5.1 Performance
•	Page load time should be under 3 seconds
•	Form submissions should process within 2 seconds
•	Search results should display within 1 second
5.2 Security
•	Secure storage of personal information
•	Teacher and admin authentication for dashboard access
•	Role-based access control
•	Protection against common web vulnerabilities
•	Secure payment processing
5.3 Usability
•	Mobile-responsive design
•	Clear error messages for form validation
•	Intuitive navigation
•	Accessible color scheme and contrasts
•	Clear visual differentiation between public, teacher, and admin areas
5.4 Reliability
•	Database backups for registration data
•	Error handling for failed operations
•	Resilience against network issues
•	Transaction handling for Acknowledgement ID generation to prevent duplicates
6. User Flows
6.1 New Registration Flow
1.	User navigates to homepage
2.	User clicks "Register Now" button
3.	Registration form displays
4.	User completes all required fields
5.	User submits form
6.	System checks for duplicate registrations 
o	If duplicate found, display message with existing Acknowledgement ID
o	If no duplicate, continue with registration
7.	System validates input
8.	System generates unique sequential Acknowledgement ID
9.	User selects payment method
10.	System processes registration and payment
11.	Confirmation screen displays with registration details and Acknowledgement ID
12.	System assigns child to appropriate class and section
6.2 Returning Child Registration Flow
1.	User navigates to homepage
2.	User clicks "Register Now" button
3.	User clicks "Click here if child has attended VBS 2024"
4.	User enters child's first name in search field
5.	System displays matching results
6.	User selects the correct child
7.	Form pre-fills with existing data
8.	User reviews and updates information if needed
9.	User submits form
10.	System checks for duplicate registrations 
o	If duplicate found, display message with existing Acknowledgement ID
o	If no duplicate, continue with registration
11.	User selects payment method
12.	System generates unique sequential Acknowledgement ID
13.	System processes registration and payment
14.	Confirmation screen displays with registration details and Acknowledgement ID
15.	System assigns child to appropriate class and section
6.3 Teacher Dashboard Flow
1.	Teacher navigates to login page (not visible from main navigation)
2.	Teacher logs in with credentials
3.	System verifies teacher role
4.	System displays teacher's assigned sections
5.	Teacher selects a section to view details
6.	System displays list of enrolled students with Acknowledgement IDs
7.	Teacher can view student details including medical information
8.	Teacher can print roster or mark attendance
6.4 Admin Dashboard Flow
1.	Admin navigates to login page (not visible from main navigation)
2.	Admin logs in with credentials
3.	System verifies admin role
4.	System displays admin dashboard overview with statistics
5.	Admin can navigate to various management sections: 
o	Class/Section Management
o	Registration Management
o	Teacher Management
o	Reports
6.5 Admin Class Management Flow
1.	Admin navigates to Class Management section
2.	System displays list of all classes with section information
3.	Admin can create new class or edit existing class
4.	Admin can create new sections within classes
5.	Admin can assign teachers to sections
6.6 Admin Section Balancing Flow
1.	Admin navigates to Section Management
2.	System displays all classes with section enrollment counts
3.	Admin selects a class to view detailed section information
4.	System displays students in each section with Acknowledgement IDs
5.	Admin selects a student to move
6.	Admin selects destination section
7.	System validates the move (age requirements, capacity)
8.	System updates the class_allocations table
9.	Updated section counts are displayed
7. Implementation Details
7.1 Frontend Components
1.	App.tsx: Main application component with routing
2.	Navigation.tsx: Site navigation menu
3.	Home.tsx: Homepage with welcome message and registration button
4.	Registration.tsx: Registration form and process handler
5.	TeacherDashboard.tsx: Teacher view for classes and students
6.	AdminDashboard.tsx: Admin management dashboard
7.	ClassManagement.tsx: Admin class and section management
8.	RegistrationManagement.tsx: Admin registration view and edit
9.	SectionBalancer.tsx: Interface for moving students between sections
10.	Auth.tsx: Authentication component for admin and teacher login
7.2 Route Protection
1.	Public Routes:
o	Home (/)
o	Registration (/register)
2.	Protected Routes:
o	Teacher Dashboard (/teacher)
o	Admin Dashboard (/admin)
o	Class Management (/admin/classes)
o	Registration Management (/admin/registrations)
o	Section Management (/admin/sections)
3.	Authentication Guard:
o	Redirect unauthorized users to login page
o	Verify user role before allowing access to protected routes
7.3 Data Flow
1.	Registration Submission:
o	Form data is collected and validated
o	System checks for duplicate registrations
o	If no duplicate, system generates next sequential Acknowledgement ID
o	Data is submitted to Supabase database (vbs2025 table)
o	Payment information is recorded
o	Registration record is created
o	Class and section allocation is determined and recorded
2.	Acknowledgement ID Generation Process:
o	Retrieve current counter value from acknowledgement_counter table
o	Increment counter value
o	Format ID as "2025" followed by incremented counter (starting at 100)
o	Update counter value in database
o	Assign generated ID to registration
o	All operations must be performed within a transaction to prevent duplicate IDs
3.	Duplicate Check Process:
o	Create a composite key from child's first_name + last_name + parent_name
o	Query vbs2025 table for matching composite key
o	If match found, retrieve the existing Acknowledgement ID
o	Return appropriate message to user
4.	Teacher Data Retrieval:
o	Teacher authentication via Supabase Auth
o	Query class_sections table filtered by teacher_id
o	For each section, query class_allocations and join with registrations
o	Display results in dashboard interface
5.	Admin Section Balancing:
o	Select child to move from source section
o	Select destination section
o	Update class_allocations record
o	Refresh section counts
7.4 Class Assignment Algorithm
The system should implement a class assignment algorithm that:
1.	Determines appropriate age group based on date of birth
2.	Queries available classes matching the age range
3.	For the matching class: 
o	Query all sections within the class
o	Check current enrollment in each section
o	Assign the child to the section with the lowest current enrollment ratio
4.	Updates the class_allocations table with the assignment
8. Admin Dashboard Requirements
8.1 Dashboard Overview
•	Total registration count
•	Registration count by class/age group
•	Payment status summary (paid vs. pending)
•	Section fill rate visualization
•	Recent registrations with Acknowledgement IDs
8.2 Class and Section Management
1.	Class List View:
o	Display all classes with age ranges
o	Show total enrollment per class
o	Show number of sections per class
o	Actions: Add, Edit, Delete classes
2.	Section Management Interface:
o	List all sections within a selected class
o	Show teacher assigned to each section
o	Show current enrollment and capacity
o	Actions: Add, Edit, Delete sections
o	Assign/reassign teachers to sections
3.	Section Balancing Tool:
o	Visual representation of section enrollment
o	Interface to select student and destination section
o	Validation to prevent invalid moves (age mismatch, capacity)
o	Update functionality to move students between sections
o	Option to bulk move students based on criteria
8.3 Registration Management
1.	Registration List:
o	Sortable and filterable list of all registrations
o	Filter by class, section, payment status
o	Search by child name, parent name, phone number
o	Display class and section assignments
o	Actions: Edit, View Details
2.	Registration Detail View:
o	Child information
o	Parent contact information
o	Payment details
o	Class/section assignment
o	Option to edit information
o	Option to change section assignment
8.4 Reports
1.	Class Roster Reports:
o	Generate printable class rosters by section
o	Include child and parent information
o	Include medical notes and allergies
2.	Enrollment Statistics:
o	Age distribution charts
o	Class/section fill rates
o	Registration trends over time
3.	Payment Reports:
o	Summary of payment methods
o	Outstanding payments
o	Total revenue
9. Teacher Dashboard Requirements
9.1 Dashboard Overview
•	List of assigned sections
•	Total student count
•	Quick access to class rosters
9.2 Section View
1.	Student List:
o	Display all students in the section
o	Show student details
o	Option to sort by name, age
2.	Roster Functionality:
o	Print class roster
o	Mark attendance (future enhancement)
o	View parent contact information
9.3 Access Restrictions
•	Teachers can only see their assigned sections
•	Teachers cannot modify student information
•	Teachers cannot move students between sections


