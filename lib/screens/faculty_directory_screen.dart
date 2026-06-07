import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FacultyDirectoryScreen extends StatelessWidget {
  const FacultyDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty & Staff Directory'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // In a production environment, this would be a dedicated endpoint or complex query
        // For Kabete Poly, we query users where role is either Teacher or Official.
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

          final docs = snapshot.data?.docs ?? [];
          
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No faculty members found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // We map docs to UserProfile or simply access map directly. 
          // For simplicity we use the map directly.
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final String name = data['fullName'] ?? 'Unknown Staff';
              final String role = data['role'] ?? 'Staff';
              final String designation = data['designation'] ?? 'Department Member';
              final String email = data['email'] ?? '';
              final String avatarUrl = data['profilePhotoUrl'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundImage: avatarUrl.isNotEmpty 
                        ? NetworkImage(avatarUrl) 
                        : const NetworkImage('https://i.pravatar.cc/150'),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        '$role - $designation', 
                        style: TextStyle(color: role == 'Official' ? Colors.red[700] : Colors.blue[700], fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.mail_outline),
                    onPressed: () {
                      // TODO: Implement mailto link launch or in-app messaging
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Contacting $name...')),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
