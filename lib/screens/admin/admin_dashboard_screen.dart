import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/class_notification.dart';
import '../../models/ticket.dart';
import '../../services/auth_provider.dart';
import '../../services/class_provider.dart';
import '../../services/firestore_service.dart';
import '../notification_screen.dart';
import '../explore_screen.dart';
import '../cubes/my_bookings_screen.dart';
import 'manage_houses_screen.dart';
import 'manage_cube_bookings_screen.dart';
import 'manage_auth_codes_screen.dart';
import 'manage_students_screen.dart';
import 'manage_tickets_screen.dart';
import 'admin_timetable_manager_screen.dart';
import '../grades/manage_grades_screen.dart';
import 'manage_alerts_screen.dart';
import 'manage_classes_screen.dart';
import 'manage_events_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  int _totalStudents = 0;
  int _totalLessons = 0;
  int _openTickets = 0;
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
        _openTickets = stats['tickets'] ?? 0;
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
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              );
            },
          ),
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
              context,
              Icons.people,
              'Manage Users',
              '$_totalStudents registered students',
              Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageStudentsScreen()),
              ),
            ),
            _buildActionCard(
              context,
              Icons.library_books,
              'Manage Lessons',
              '$_totalLessons lessons archived',
              Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExploreScreen()),
              ),
            ),
            _buildActionCard(
              context,
              Icons.vpn_key,
              'Auth Codes',
              'Generate registration keys',
              Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ManageAuthCodesScreen(),
                ),
              ),
            ),
            _buildActionCard(
              context,
              Icons.calendar_month,
              'Timetable Manager',
              'Add/edit schedule entries',
              Colors.cyan,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminTimetableManagerScreen(),
                ),
              ),
            ),
            _buildActionCard(
              context,
              Icons.class_,
              'Manage Classes',
              'Create & delete cohorts',
              Colors.deepOrange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageClassesScreen()),
              ),
            ),
            _buildActionCard(
              context,
              Icons.assignment,
              'Manage Grades',
              'Enter & view student grades',
              Colors.amber,
              onTap: () => _selectClassAndNavigate(context),
            ),
            _buildActionCard(
              context,
              Icons.confirmation_number,
              'Manage Tickets',
              'Help requests, errors, feedback',
              Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageTicketsScreen()),
              ),
            ),
            _buildActionCard(
              context,
              Icons.gavel,
              'Forum Moderation',
              '$_openTickets pending reports & tickets',
              Colors.red,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageTicketsScreen()),
              ),
            ),
            _buildActionCard(
              context,
              Icons.workspaces,
              'Manage Houses',
              'Configure houses & cube capacities',
              Colors.indigo,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageHousesScreen()),
              ),
            ),
            _buildActionCard(
              context,
              Icons.book_online,
              'Cube Bookings',
              'View & manage all bookings',
              Colors.deepPurple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ManageCubeBookingsScreen(),
                ),
              ),
            ),
            _buildActionCard(
              context,
              Icons.photo_library,
              'Event Gallery',
              'Create & manage event photo galleries',
              Colors.pink,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageEventsScreen()),
              ),
            ),
            _buildActionCard(
              context,
              Icons.campaign,
              'Announcements',
              'Send push notifications',
              Colors.green,
              onTap: () => _showAnnouncementDialog(context),
            ),
            _buildActionCard(
              context,
              Icons.notifications_active,
              'Send Alert',
              'Target user, class, or all',
              Colors.indigo,
              onTap: () => _showAlertDialog(context),
            ),
            _buildActionCard(
              context,
              Icons.manage_history,
              'Manage Alerts',
              'View, edit & delete sent items',
              Colors.brown,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageAlertsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    if (_isLoadingStats) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            context,
            'Total Students',
            '$_totalStudents',
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatItem(
            context,
            'Total Lessons',
            '$_totalLessons',
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String title,
    String count,
    Color color,
  ) {
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
          Text(
            count,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color, {
    VoidCallback? onTap,
  }) {
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
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
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
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: messageController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'general',
                          child: Text('General Info'),
                        ),
                        DropdownMenuItem(value: 'event', child: Text('Event')),
                        DropdownMenuItem(
                          value: 'deadline',
                          child: Text('Deadline'),
                        ),
                        DropdownMenuItem(
                          value: 'canceled',
                          child: Text('Cancellation'),
                        ),
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
                    if (titleController.text.trim().isEmpty ||
                        messageController.text.trim().isEmpty)
                      return;
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
                        const SnackBar(
                          content: Text('Announcement broadcasted!'),
                        ),
                      );
                    }
                  },
                  child: const Text('Broadcast'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAlertDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    final userIdCtrl = TextEditingController();
    String targetType = 'all';
    String alertType = 'info';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Send Alert'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Alert Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: alertType,
                      decoration: const InputDecoration(
                        labelText: 'Alert Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'info',
                          child: Text('Information'),
                        ),
                        DropdownMenuItem(
                          value: 'warning',
                          child: Text('Warning'),
                        ),
                        DropdownMenuItem(
                          value: 'class_update',
                          child: Text('Class Update'),
                        ),
                      ],
                      onChanged: (v) => setState(() => alertType = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: targetType,
                      decoration: const InputDecoration(
                        labelText: 'Send To',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All Users'),
                        ),
                        DropdownMenuItem(
                          value: 'user',
                          child: Text('Specific User'),
                        ),
                        DropdownMenuItem(
                          value: 'regNo',
                          child: Text('Registration Number'),
                        ),
                      ],
                      onChanged: (v) => setState(() => targetType = v!),
                    ),
                    if (targetType == 'user') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: userIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'User ID',
                          border: OutlineInputBorder(),
                          hintText: 'Enter the Firebase user UID',
                        ),
                      ),
                    ],
                    if (targetType == 'regNo') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: userIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Registration Number',
                          border: OutlineInputBorder(),
                          hintText: 'e.g. C101/01/2024',
                        ),
                      ),
                    ],
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
                    if (titleCtrl.text.trim().isEmpty ||
                        messageCtrl.text.trim().isEmpty)
                      return;
                    if ((targetType == 'user' || targetType == 'regNo') &&
                        userIdCtrl.text.trim().isEmpty)
                      return;
                    try {
                      final sender = context.read<AuthProvider>().currentUser;
                      final alert = Alert(
                        id: '',
                        title: titleCtrl.text.trim(),
                        message: messageCtrl.text.trim(),
                        type: alertType,
                        targetType: targetType,
                        targetId: targetType == 'user' || targetType == 'regNo'
                            ? userIdCtrl.text.trim()
                            : null,
                        senderId: context.read<AuthProvider>().currentUserId,
                        senderName: sender?.fullName ?? 'Admin',
                        timestamp: DateTime.now(),
                      );
                      await _firestoreService.sendAlert(alert);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Alert sent!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Send Alert'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _selectClassAndNavigate(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;

    if (user == null) return;

    if (!user.isAdmin && !user.isTeacher) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only teachers and officials can manage grades'),
        ),
      );
      return;
    }

    final allClasses = context.read<ClassProvider>().availableClasses;
    if (user.isAdmin) {
      _showClassPicker(context, allClasses);
    } else {
      final myClasses = user.enrolledClasses
          .where(allClasses.contains)
          .toList();
      if (myClasses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No classes assigned to your account')),
        );
        return;
      }
      _showClassPicker(context, myClasses);
    }
  }

  void _showClassPicker(BuildContext context, List<String> classes) {
    if (classes.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManageGradesScreen(classId: classes.first),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Class'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: classes.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(classes[i]),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManageGradesScreen(classId: classes[i]),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
