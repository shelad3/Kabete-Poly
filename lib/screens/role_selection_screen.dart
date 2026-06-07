import 'package:flutter/material.dart';
import 'registration_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  final Map<String, String> _rolePasswords = const {
    'Leader': 'LEAD2026',
    'Teacher': 'TEACHER1',
    'Official': 'ADMIN001',
  };

  void _handleRoleSelection(BuildContext context, String role) {
    if (role == 'Student') {
      _navigateToRegistration(context, role);
      return;
    }

    // Elevated Roles Require Password
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter $role Access Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This role requires an 8-character security key to register.'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Security Key',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (passwordController.text == _rolePasswords[role]) {
                  Navigator.pop(context); // Close dialog
                  _navigateToRegistration(context, role);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid Security Key!'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Verify'),
            ),
          ],
        );
      }
    );
  }

  void _navigateToRegistration(BuildContext context, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrationScreen(selectedRole: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Registration Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome to Kabete Poly!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please select your role to continue registration. Elevated profiles require an access key.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 48),
            _buildRoleButton(context, 'Student', Icons.school, 'Standard class archive access'),
            const SizedBox(height: 16),
            _buildRoleButton(context, 'Leader', Icons.star, 'For Prefects and Class Reps'),
            const SizedBox(height: 16),
            _buildRoleButton(context, 'Teacher', Icons.menu_book, 'Post lessons and manage schedule'),
            const SizedBox(height: 16),
            _buildRoleButton(context, 'Official', Icons.admin_panel_settings, 'Global administrative access'),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleButton(BuildContext context, String role, IconData icon, String subtitle) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _handleRoleSelection(context, role),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: Icon(icon, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
