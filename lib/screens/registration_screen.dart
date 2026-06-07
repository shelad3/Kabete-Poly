import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_provider.dart';
import '../services/storage_service.dart';
import '../models/user_profile.dart';
import '../utils/timetable_data.dart';
import 'home_screen.dart';
import 'admin/admin_home_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final String selectedRole;
  const RegistrationScreen({super.key, required this.selectedRole});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _regNumController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Role specific fields
  final _designationController = TextEditingController(); // For Leaders, Teachers, Officials
  bool _isHostelResident = false; // For Students and Leaders
  
  // Cohort Selection from Timetable
  String? _selectedCohort;
  final _customCohortController = TextEditingController();
  bool _useCustomCohort = false;

  bool _isLoading = false;
  File? _profileImage;
  
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
    );
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null
                      ? const Icon(Icons.add_a_photo, size: 40, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _pickImage,
                child: const Text('Upload Profile Picture'),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _regNumController,
                decoration: const InputDecoration(labelText: 'Registration Number (e.g., EE-2024-001)'),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
                  ),
                ],
                validator: (val) => val == null || val.trim().isEmpty ? 'Registration Number is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Full Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(labelText: 'Mobile Number'),
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.trim().isEmpty ? 'Mobile Number is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email Address'),
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Email is required';
                  if (!val.contains('@')) return 'Enter a valid email address';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Password is required';
                  if (val.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                validator: (val) {
                  if (val != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Conditional Form Fields based on Roles
              if (widget.selectedRole != 'Student') ...[
                TextFormField(
                  controller: _designationController,
                  decoration: InputDecoration(
                    labelText: widget.selectedRole == 'Teacher' ? 'Department' : 'Leadership Designation (e.g., Class Rep)',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'This field is required' : null,
                ),
                const SizedBox(height: 16),
              ],
              
              if (widget.selectedRole == 'Student' || widget.selectedRole == 'Leader') ...[
                DropdownButtonFormField<String>(
                  key: ValueKey(_useCustomCohort),
                  initialValue: _useCustomCohort ? null : _selectedCohort,
                  decoration: const InputDecoration(
                    labelText: 'Select Your Class Cohort *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.school),
                  ),
                  isExpanded: true,
                  hint: const Text('Choose your class from the timetable'),
                  items: [
                    ...TimetableData.allCohortCodes.map((code) {
                      return DropdownMenuItem(value: code, child: Text(code, style: const TextStyle(fontSize: 14)));
                    }),
                    const DropdownMenuItem(
                      value: '__custom__',
                      child: Text('Other (specify below)', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      if (val == '__custom__') {
                        _useCustomCohort = true;
                        _selectedCohort = null;
                      } else {
                        _useCustomCohort = false;
                        _selectedCohort = val;
                      }
                    });
                  },
                  validator: (val) {
                    if (!_useCustomCohort && val == null) return 'Please select your class cohort';
                    return null;
                  },
                ),
                if (_useCustomCohort) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customCohortController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Your Class Cohort Code *',
                      hintText: 'e.g., EET 600 M24',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
                      ),
                    ],
                    validator: (val) {
                      if (_useCustomCohort && (val == null || val.trim().isEmpty)) {
                        return 'Please enter your class cohort';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
              ],
              
              if (widget.selectedRole == 'Student' || widget.selectedRole == 'Leader') ...[
               SwitchListTile(
                 title: const Text('Stay in Hostel?'),
                 value: _isHostelResident,
                 onChanged: (val) => setState(() => _isHostelResident = val),
                 activeThumbColor: Theme.of(context).primaryColor,
                 contentPadding: EdgeInsets.zero,
               ),
               const SizedBox(height: 32),
              ],
              
              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Create Account'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    
    try {
      String photoUrl = '';
      
      // Upload image if provided
      if (_profileImage != null) {
        final regNo = _regNumController.text.trim().toUpperCase();
        final path = 'profiles/img_$regNo.jpg';
        final uploadedUrl = await _storageService.uploadImage(_profileImage!, path);
        if (uploadedUrl != null) {
          photoUrl = uploadedUrl;
        }
      }

      // Use selected cohort from timetable dropdown
      List<String> enrolled = [];
      if (widget.selectedRole == 'Student' || widget.selectedRole == 'Leader') {
        final cohortCode = _useCustomCohort
            ? _customCohortController.text.trim().toUpperCase()
            : _selectedCohort;
        if (cohortCode != null && cohortCode.isNotEmpty) {
          enrolled.add(cohortCode);
        }
      }

      final profile = UserProfile(
        registrationNumber: _regNumController.text.trim().toUpperCase(),
        fullName: _fullNameController.text.trim(),
        profilePhotoUrl: photoUrl,
        mobileNumber: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        isHostelResident: (widget.selectedRole == 'Student' || widget.selectedRole == 'Leader') ? _isHostelResident : false,
        role: widget.selectedRole,
        designation: widget.selectedRole != 'Student' ? _designationController.text.trim() : null,
        enrolledClasses: enrolled,
      );
      
      await authProvider.register(profile, _passwordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully!'), backgroundColor: Colors.green),
        );
        final user = authProvider.currentUser;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => (user?.isAdmin == true) ? const AdminHomeScreen() : const HomeScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

}
