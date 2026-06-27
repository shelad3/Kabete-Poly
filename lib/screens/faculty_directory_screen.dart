import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';

class FacultyDirectoryScreen extends StatefulWidget {
  const FacultyDirectoryScreen({super.key});

  @override
  State<FacultyDirectoryScreen> createState() => _FacultyDirectoryScreenState();
}

class _FacultyDirectoryScreenState extends State<FacultyDirectoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedDepartment;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final canView = user != null && (user.isTeacher || user.isAdmin);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty & Staff Directory'),
      ),
      body: canView ? _buildDirectory() : _buildAccessDenied(),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Access Restricted', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Only teachers and officials can view the directory.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildDirectory() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', whereIn: ['Teacher', 'Official'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading directory.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<Map<String, dynamic>> allDocs =
              (snapshot.data?.docs ?? []).map((d) => d.data() as Map<String, dynamic>).toList();

          final departments = allDocs
              .map((d) => d['designation'] as String? ?? 'Department Member')
              .toSet()
              .toList()
            ..sort();

          var filtered = allDocs.where((d) {
            final name = (d['fullName'] as String? ?? '').toLowerCase();
            final role = (d['role'] as String? ?? '').toLowerCase();
            final dept = (d['designation'] as String? ?? '').toLowerCase();
            final email = (d['email'] as String? ?? '').toLowerCase();

            final matchesSearch = _searchQuery.isEmpty ||
                name.contains(_searchQuery.toLowerCase()) ||
                role.contains(_searchQuery.toLowerCase()) ||
                dept.contains(_searchQuery.toLowerCase()) ||
                email.contains(_searchQuery.toLowerCase());

            final matchesDept = _selectedDepartment == null || d['designation'] == _selectedDepartment;

            return matchesSearch && matchesDept;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name, role, or department...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), () {
                      setState(() => _searchQuery = v);
                    });
                  },
                ),
              ),
              if (departments.length > 1)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildFilterChip('All', null),
                      ...departments.map((d) => _buildFilterChip(d, d)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No faculty members found.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final data = filtered[index];
                          final String name = data['fullName'] ?? 'Unknown Staff';
                          final String role = data['role'] ?? 'Staff';
                          final String designation = data['designation'] ?? 'Department Member';
                          final String email = data['email'] ?? '';
                          final String phone = data['mobileNumber'] ?? '';
                          final String avatarUrl = data['profilePhotoUrl'] ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                    child: avatarUrl.isEmpty
                                        ? Text(name[0].toUpperCase(), style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold))
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$role - $designation',
                                          style: TextStyle(
                                            color: role == 'Official' ? Colors.red[700] : Colors.blue[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (email.isNotEmpty)
                                          Row(
                                            children: [
                                              Icon(Icons.email_outlined, size: 14, color: Colors.grey[500]),
                                              const SizedBox(width: 4),
                                              Flexible(child: Text(email, style: const TextStyle(fontSize: 13, color: Colors.grey))),
                                            ],
                                          ),
                                        if (phone.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(Icons.phone_outlined, size: 14, color: Colors.grey[500]),
                                              const SizedBox(width: 4),
                                              Text(phone, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (email.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.mail_outline),
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Contacting $name...')),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      );
  }

  Widget _buildFilterChip(String label, String? value) {
    final selected = _selectedDepartment == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedDepartment = selected ? null : value),
      ),
    );
  }
}
