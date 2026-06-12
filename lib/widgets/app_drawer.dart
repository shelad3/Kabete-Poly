import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/class_provider.dart';
import '../screens/login_screen.dart';
import '../screens/my_devices_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final classProvider = context.watch<ClassProvider>();
    final user = auth.currentUser;

    if (user == null) return const SizedBox.shrink();

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            accountName: Text('${user.fullName} (${user.role})', style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(user.email),
            currentAccountPicture: user.profilePhotoUrl.isNotEmpty 
                ? CircleAvatar(backgroundImage: NetworkImage(user.profilePhotoUrl))
                : CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(user.fullName[0].toUpperCase(), style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 24)),
                  ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('MY CLASSES', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          
          // Class Context Switches
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildClassTile(context, classProvider, 'Global / General Assembly'),
                if (user.enrolledClasses.isNotEmpty)
                  ...user.enrolledClasses.map((className) => _buildClassTile(context, classProvider, className)),
                if (user.enrolledClasses.isEmpty && user.role != 'Official' && user.role != 'Teacher')
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text('You are not enrolled in any specific cohorts yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                  
                if (user.role == 'Official' || user.role == 'Teacher' || user.isLeader) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      (user.role == 'Official' || user.role == 'Teacher')
                          ? 'ADMINISTRATION (ALL CLASSES)'
                          : 'EXPLORE OTHER COHORTS',
                      style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)
                    ),
                  ),
                  ...classProvider.availableClasses
                      .where((c) => c != 'Global / General Assembly' && !user.enrolledClasses.contains(c))
                      .map((className) => _buildClassTile(context, classProvider, className)),
                ],
              ],
            ),
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.devices, color: Colors.blueGrey),
            title: const Text('My Devices'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyDevicesScreen()));
            },
          ),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildClassTile(BuildContext context, ClassProvider provider, String className) {
    bool isSelected = provider.currentClass == className;
    return Container(
      color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
      child: ListTile(
        leading: Icon(
          className == 'Global / General Assembly' ? Icons.public : Icons.class_,
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[700],
        ),
        title: Text(
          className,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Theme.of(context).primaryColor : null,
          ),
        ),
        trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).primaryColor, size: 20) : null,
        onTap: () {
          provider.setClassContext(className);
          Navigator.pop(context); // Close the drawer automatically
        },
      ),
    );
  }
}
