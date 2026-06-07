import 'package:flutter/material.dart';
import '../../models/class_notification.dart';
import '../../services/firestore_service.dart';
import '../notification_screen.dart';
import '../explore_screen.dart';
import 'manage_auth_codes_screen.dart';
import 'manage_students_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  int _totalStudents = 0;
  int _totalLessons = 0;
  int _flaggedMessages = 0; // Future dynamic query
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _firestoreService.getAdminStats();
    if (mounted) {
      setState(() {
        _totalStudents = stats['students'] ?? 0;
        _totalLessons = stats['lessons'] ?? 0;
        _flaggedMessages = 0; // Replace when forum stats are tracked
        _isLoadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NotificationScreen()),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsRow(context),
            const SizedBox(height: 24),
            _buildActionCard(
              context, Icons.people, 'Manage Students', '$_totalStudents registered students', Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageStudentsScreen())),
            ),
            _buildActionCard(context, Icons.library_books, 'Manage Lessons', '$_totalLessons lessons archived', Colors.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreScreen())),
            ),
            _buildActionCard(context, Icons.vpn_key, 'Auth Codes', 'Generate registration keys', Colors.purple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageAuthCodesScreen())),
            ),
            _buildActionCard(context, Icons.gavel, 'Forum Moderation', '$_flaggedMessages flagged messages', Colors.red),
            _buildActionCard(
              context, 
              Icons.campaign, 
              'Global Announcements', 
              'Send push notifications', 
              Colors.green,
              onTap: () => _showAnnouncementDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    if (_isLoadingStats) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(),
      ));
    }
    
    return Row(
      children: [
        Expanded(child: _buildStatItem(context, 'Total Students', '$_totalStudents', Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatItem(context, 'Total Lessons', '$_totalLessons', Colors.orange)),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String title, String count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[800], fontSize: 14)),
          const SizedBox(height: 8),
          Text(count, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String title, String subtitle, Color color, {VoidCallback? onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showAnnouncementDialog(BuildContext context) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String selectedType = 'general';
    String targetClass = 'General';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('New Announcement'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: messageController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'general', child: Text('General Info')),
                        DropdownMenuItem(value: 'event', child: Text('Event')),
                        DropdownMenuItem(value: 'deadline', child: Text('Deadline')),
                        DropdownMenuItem(value: 'canceled', child: Text('Cancellation')),
                      ],
                      onChanged: (val) => setState(() => selectedType = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty || messageController.text.trim().isEmpty) return;
                    
                    final notification = ClassNotification(
                      id: '',
                      classId: targetClass,
                      title: titleController.text.trim(),
                      message: messageController.text.trim(),
                      type: selectedType,
                      timestamp: DateTime.now(),
                    );

                    await _firestoreService.sendNotification(notification);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Announcement successfully broadcasted!')),
                      );
                    }
                  },
                  child: const Text('Broadcast'),
                ),
              ],
            );
          }
        );
      }
    );
  }
}
