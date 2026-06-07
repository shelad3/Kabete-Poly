import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_code_service.dart';
import 'registration_screen.dart';
import 'dart:async';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _handleRoleSelection(BuildContext context, String role) {
    if (role == 'Student') {
      _navigateToRegistration(context, role);
      return;
    }
    final passwordController = TextEditingController();
    final service = AuthCodeService();
    showDialog(
      context: context,
      builder: (context) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setDState) {
            return AlertDialog(
              title: Text('Enter $role Access Key'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('This role requires a security key to register.'),
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
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setDState(() => isLoading = true);
                          try {
                            final verifiedRole = await service.verifyCode(passwordController.text);
                            if (verifiedRole != null && verifiedRole == role) {
                              await service.markCodeUsed(passwordController.text, role);
                              if (context.mounted) {
                                // Show success, then navigate
                                Navigator.pop(context);
                                _showVerifiedDialog(context, role);
                              }
                            } else {
                              setDState(() => isLoading = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invalid or expired Security Key!'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          } catch (e) {
                            setDState(() => isLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify'),
                ),
              ],
            );
          },
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

  void _showVerifiedDialog(BuildContext context, String role) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Access Key Verified!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your $role key is valid. Redirecting to registration...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    // Navigate after a brief pause so user sees the success
    Future.delayed(const Duration(seconds: 1), () {
      if (context.mounted) {
        Navigator.pop(context); // close verified dialog
        _navigateToRegistration(context, role);
      }
    });
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
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Authentication code needed for elevated roles',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blue[700]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse('mailto:sheldonramu8@gmail.com?subject=Access%20Key%20Request&body=Role:%0ARegistration%20Number:');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      children: [
                        const TextSpan(text: 'Contact '),
                        TextSpan(
                          text: 'sheldonramu8@gmail.com',
                          style: TextStyle(
                            color: Colors.blue[700],
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(text: ' with your role and registration number to receive your access key.'),
                      ],
                    ),
                  ),
                ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
