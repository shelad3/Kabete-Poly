import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageStudentsScreen extends StatelessWidget {
  const ManageStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Students'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('fullName')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snap.data?.docs ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('No registered users'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final data = users[index].data() as Map<String, dynamic>;
              final name = data['fullName'] ?? 'Unknown';
              final role = data['role'] ?? 'Student';
              final email = data['email'] ?? '';
              final regNo = data['registrationNumber'] ?? '';
              final classes = List<String>.from(data['enrolledClasses'] ?? []);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _roleColor(role).withValues(alpha: 0.1),
                    child: Text(name.toString()[0].toUpperCase(),
                        style: TextStyle(color: _roleColor(role), fontWeight: FontWeight.bold)),
                  ),
                  title: Text('$name ($role)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$regNo · $email\n${classes.length} class(es)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Official':
        return Colors.red;
      case 'Teacher':
        return Colors.orange;
      case 'Leader':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
}
