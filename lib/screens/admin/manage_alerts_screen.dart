import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/class_notification.dart';
import '../../models/ticket.dart';

class ManageAlertsScreen extends StatefulWidget {
  const ManageAlertsScreen({super.key});

  @override
  State<ManageAlertsScreen> createState() => _ManageAlertsScreenState();
}

class _ManageAlertsScreenState extends State<ManageAlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Announcements & Alerts'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Announcements', icon: Icon(Icons.campaign)),
            Tab(text: 'Alerts', icon: Icon(Icons.notifications_active)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAnnouncementsTab(),
          _buildAlertsTab(),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.campaign_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No announcements yet', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final notification = ClassNotification.fromJson(data, doc.id);
            return _buildNotificationItem(context, notification, doc.id);
          },
        );
      },
    );
  }

  Widget _buildAlertsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No alerts sent yet', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final alert = Alert.fromJson(data, doc.id);
            return _buildAlertItem(context, alert, doc.id);
          },
        );
      },
    );
  }

  Widget _buildNotificationItem(BuildContext context, ClassNotification notification, String docId) {
    Color typeColor;
    IconData typeIcon;
    switch (notification.type) {
      case 'canceled':
        typeColor = Colors.red;
        typeIcon = Icons.cancel_outlined;
        break;
      case 'event':
        typeColor = Colors.blue;
        typeIcon = Icons.event;
        break;
      case 'deadline':
        typeColor = Colors.orange;
        typeIcon = Icons.timer_outlined;
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.notifications_none;
    }

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: typeColor.withValues(alpha: 0.1),
          child: Icon(typeIcon, color: typeColor),
        ),
        title: Text(notification.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(notification.timeAgo, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(notification.type, style: TextStyle(fontSize: 10, color: typeColor)),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditNotificationDialog(context, notification, docId);
            } else if (value == 'delete') {
              _confirmDelete(context, 'notification', docId);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: ListTile(
              leading: Icon(Icons.edit, size: 20),
              title: Text('Edit'),
              dense: true,
            )),
            const PopupMenuItem(value: 'delete', child: ListTile(
              leading: Icon(Icons.delete, color: Colors.red, size: 20),
              title: Text('Delete', style: TextStyle(color: Colors.red)),
              dense: true,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(BuildContext context, Alert alert, String docId) {
    Color typeColor;
    IconData typeIcon;
    switch (alert.type) {
      case 'warning':
        typeColor = Colors.orange;
        typeIcon = Icons.warning_amber;
        break;
      case 'class_update':
        typeColor = Colors.blue;
        typeIcon = Icons.school;
        break;
      default:
        typeColor = Colors.indigo;
        typeIcon = Icons.campaign;
    }

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: typeColor.withValues(alpha: 0.1),
          child: Icon(typeIcon, color: typeColor),
        ),
        title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.message, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'To: ${alert.targetType}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                Text(
                  'By: ${alert.senderName}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditAlertDialog(context, alert, docId);
            } else if (value == 'delete') {
              _confirmDelete(context, 'alert', docId);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: ListTile(
              leading: Icon(Icons.edit, size: 20),
              title: Text('Edit'),
              dense: true,
            )),
            const PopupMenuItem(value: 'delete', child: ListTile(
              leading: Icon(Icons.delete, color: Colors.red, size: 20),
              title: Text('Delete', style: TextStyle(color: Colors.red)),
              dense: true,
            )),
          ],
        ),
      ),
    );
  }

  void _showEditNotificationDialog(BuildContext context, ClassNotification notification, String docId) {
    final titleController = TextEditingController(text: notification.title);
    final messageController = TextEditingController(text: notification.message);
    String selectedType = notification.type;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit Announcement'),
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
                  onChanged: (v) => setState(() => selectedType = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty || messageController.text.trim().isEmpty) return;
                await FirebaseFirestore.instance.collection('notifications').doc(docId).update({
                  'title': titleController.text.trim(),
                  'message': messageController.text.trim(),
                  'type': selectedType,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Announcement updated')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAlertDialog(BuildContext context, Alert alert, String docId) {
    final titleController = TextEditingController(text: alert.title);
    final messageController = TextEditingController(text: alert.message);
    String alertType = alert.type;
    String targetType = alert.targetType;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit Alert'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: alertType,
                  decoration: const InputDecoration(labelText: 'Alert Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'info', child: Text('Information')),
                    DropdownMenuItem(value: 'warning', child: Text('Warning')),
                    DropdownMenuItem(value: 'class_update', child: Text('Class Update')),
                  ],
                  onChanged: (v) => setState(() => alertType = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: targetType,
                  decoration: const InputDecoration(labelText: 'Target', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                    DropdownMenuItem(value: 'class', child: Text('Class')),
                    DropdownMenuItem(value: 'user', child: Text('User')),
                    DropdownMenuItem(value: 'regNo', child: Text('Reg Number')),
                  ],
                  onChanged: (v) => setState(() => targetType = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty || messageController.text.trim().isEmpty) return;
                await FirebaseFirestore.instance.collection('alerts').doc(docId).update({
                  'title': titleController.text.trim(),
                  'message': messageController.text.trim(),
                  'type': alertType,
                  'targetType': targetType,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alert updated')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String type, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete this ${type} permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final collection = type == 'notification' ? 'notifications' : 'alerts';
              await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$type deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
