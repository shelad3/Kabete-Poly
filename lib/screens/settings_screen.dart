import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../widgets/app_drawer.dart';
import 'faculty_directory_screen.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Profile & Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildIDCard(context, user),
            const SizedBox(height: 24),
            _buildSettingsSection(context, 'Account Details', [
              _buildSettingItem(context, Icons.email_outlined, 'Email', user?.email ?? '-'),
              _buildSettingItem(context, Icons.phone_android_outlined, 'Mobile', user?.mobileNumber ?? '-'),
              _buildSettingItem(context, Icons.admin_panel_settings_outlined, 'Global Role', user?.role ?? 'User'),
              if (user?.role == 'Student' || user?.role == 'Leader')
                _buildSettingItem(context, Icons.house_outlined, 'Hostel Status', user?.isHostelResident == true ? 'Hostel Resident' : 'Day Scholar'),
            ]),
            _buildSettingsSection(context, 'App Preferences', [
              ListTile(
                leading: Icon(Icons.lock_reset, color: Theme.of(context).primaryColor),
                title: const Text('Change Password', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: () => _showPasswordResetDialog(context, user?.email),
              ),
              ListTile(
                leading: const Icon(Icons.system_update_alt, color: Colors.blueAccent),
                title: const Text('Check for Updates', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.refresh, size: 18, color: Colors.blueAccent),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checking latest release...')));
                  UpdateService.checkForUpdates(context, showNoUpdateMsg: true);
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSettingsSection(context, 'Institution', [
              ListTile(
                leading: const Icon(Icons.contact_phone_outlined, color: Colors.grey),
                title: const Text('Faculty & Staff Directory', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FacultyDirectoryScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.grey),
                title: const Text('About Kabete Poly App', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: () => _showAboutDialog(context),
              ),
            ]),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton(
                onPressed: () => context.read<AuthProvider>().logout(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: Colors.red.withValues(alpha: 0.05),
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Secure Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildIDCard(BuildContext context, user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(Icons.school, size: 150, color: Colors.white.withValues(alpha: 0.1)),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white24,
                        backgroundImage: user?.profilePhotoUrl.isNotEmpty == true 
                          ? NetworkImage(user!.profilePhotoUrl) 
                          : null,
                        child: user?.profilePhotoUrl.isEmpty == true 
                          ? const Icon(Icons.person, size: 40, color: Colors.white) 
                          : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            user?.fullName ?? 'Student Name',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              user?.registrationNumber ?? 'EE-XXXX-XXX',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildIDStat('ROLE', user?.role ?? 'Student'),
                    if (user?.role != 'Student' && user?.designation != null)
                      _buildIDStat('DESIGNATION', user!.designation!),
                    _buildIDStat('STATUS', 'Active', color: Colors.greenAccent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIDStat(String label, String value, {Color color = Colors.white}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingItem(BuildContext context, IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  void _showPasswordResetDialog(BuildContext context, String? email) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Text('A password reset link will be sent to:\n$email'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await context.read<AuthProvider>().sendPasswordResetEmail(email!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent. Check your inbox.')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 10),
            Text('About Kabete Poly'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.1+2', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('Kabete Poly App provides students and faculty with scheduling, document sharing, and real-time alerts.'),
            SizedBox(height: 10),
            Text('Built with Flutter & Firebase.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
        ],
      ),
    );
  }
}
