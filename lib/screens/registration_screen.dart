import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_provider.dart';
import '../services/storage_service.dart';
import '../models/user_profile.dart';
import '../utils/role_data.dart';
import '../services/class_provider.dart';
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
  String? _selectedDesignation; // For Leaders, Teachers, Officials
  bool _isCustomDesignation = false;
  final _customDesignationController = TextEditingController();
  bool _isHostelResident = false; // For Students and Leaders
  
  // Cohort Selection from Timetable
  String? _selectedCohort;
  bool _cohortMissing = false;

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
              
              if (widget.selectedRole != 'Student') ...[
                DropdownButtonFormField<String>(
                  value: _selectedDesignation,
                  decoration: InputDecoration(
                    labelText: widget.selectedRole == 'Teacher'
                        ? 'Department'
                        : widget.selectedRole == 'Official'
                            ? 'Office / Role'
                            : 'Leadership Position',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      widget.selectedRole == 'Teacher'
                          ? Icons.school
                          : widget.selectedRole == 'Official'
                              ? Icons.admin_panel_settings
                              : Icons.star,
                    ),
                  ),
                  isExpanded: true,
                  hint: Text(widget.selectedRole == 'Teacher'
                      ? 'Select your department'
                      : widget.selectedRole == 'Official'
                          ? 'Select your office'
                          : 'Select your position'),
                  items: [
                    for (final section in RoleData.sectionsForRole(widget.selectedRole))
                      ...[
                        DropdownMenuItem<String>(
                          enabled: false,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              section.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        for (final item in section.items)
                          DropdownMenuItem(
                            value: item,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(item, style: const TextStyle(fontSize: 14)),
                            ),
                          ),
                      ],
                    DropdownMenuItem(
                      enabled: true,
                      value: '__custom__',
                      child: Row(
                        children: [
                          const Icon(Icons.edit, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Other (specify)',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _isCustomDesignation = val == '__custom__';
                      if (!_isCustomDesignation) {
                        _selectedDesignation = val;
                      } else {
                        _selectedDesignation = null;
                      }
                    });
                  },
                  validator: (val) {
                    if (_isCustomDesignation) return null;
                    if (val == null) return 'Please select an option';
                    return null;
                  },
                ),
                if (_isCustomDesignation) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customDesignationController,
                    decoration: InputDecoration(
                      labelText: 'Specify your ${widget.selectedRole == 'Teacher' ? 'department' : widget.selectedRole == 'Official' ? 'office' : 'position'}',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.edit),
                    ),
                    validator: (val) {
                      if (_isCustomDesignation && (val == null || val.trim().isEmpty)) {
                        return 'Please specify your designation';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
              ],
              
               if (widget.selectedRole == 'Student' || widget.selectedRole == 'Leader') ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedCohort,
                  decoration: const InputDecoration(
                    labelText: 'Select Your Class Cohort *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.school),
                  ),
                  isExpanded: true,
                  hint: const Text('Choose your class from the timetable'),
                  items: [
                    ...context.read<ClassProvider>().availableClasses
                        .where((c) => c != 'Global / General Assembly')
                        .map((code) {
                      return DropdownMenuItem(value: code, child: Text(code, style: const TextStyle(fontSize: 14)));
                    }),
                    const DropdownMenuItem(
                      value: '__missing__',
                      child: Text('My class is not listed',
                          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.orange)),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      if (val == '__missing__') {
                        _selectedCohort = null;
                        _cohortMissing = true;
                      } else {
                        _selectedCohort = val;
                        _cohortMissing = false;
                      }
                    });
                  },
                  validator: (val) {
                    if (val == null) return 'Please select your class cohort';
                    return null;
                  },
                ),
                if (_cohortMissing) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse('mailto:sheldonramu8@gmail.com?subject=Missing%20Cohort%20Request&body=Cohort%20Code:%0ADepartment:%0ACourse:');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                                children: [
                                  const TextSpan(text: 'Missing a class? Email '),
                                  TextSpan(
                                    text: 'sheldonramu8@gmail.com',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const TextSpan(
                                      text: ' with your cohort code and department details to have it added.'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
        if (_selectedCohort != null && _selectedCohort!.isNotEmpty) {
          enrolled.add(_selectedCohort!);
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
        designation: widget.selectedRole != 'Student'
            ? (_isCustomDesignation
                ? _customDesignationController.text.trim()
                : _selectedDesignation)
            : null,
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
