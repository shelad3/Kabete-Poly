import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ticket.dart';
import '../models/class_notification.dart';
import '../services/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/class_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/shimmer_loading.dart';

class NotificationScreen extends StatelessWidget {
  NotificationScreen({super.key});

  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Notification Center'),
      ),
      body: Consumer2<AuthProvider, ClassProvider>(
        builder: (context, authProvider, classProvider, _) {
          final user = authProvider.currentUser;
          final regNo = user?.registrationNumber ?? '';
          final userId = authProvider.currentUserId;
          return Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ClassNotification>>(
                  stream: _firestoreService.getNotificationsStream(classProvider.currentClass),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Error loading notifications.'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const ShimmerNotificationList();
                    }
                    final notifications = snapshot.data ?? [];
                    if (notifications.isEmpty) {
                      return const Center(child: Text('No new notifications.'));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: notifications.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final notify = notifications[index];
                        return _buildNotificationCard(context, notify);
                      },
                    );
                  },
                ),
              ),
              if (user != null && userId.isNotEmpty)
                Expanded(
                  child: StreamBuilder<List<Alert>>(
                    stream: _firestoreService.getAlertsForUser(userId, regNo, user.enrolledClasses),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const ShimmerNotificationList();
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error loading alerts: ${snapshot.error}'));
                      }
                      final alerts = snapshot.data ?? [];
                      if (alerts.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Text('Alerts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                          ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              itemCount: alerts.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final alert = alerts[index];
                                return _buildAlertCard(context, alert);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, ClassNotification notify) {
    Color color;
    IconData icon;

    switch (notify.type) {
      case 'canceled':
        color = Colors.red;
        icon = Icons.cancel_outlined;
        break;
      case 'event':
        color = Colors.blue;
        icon = Icons.event;
        break;
      case 'deadline':
        color = Colors.orange;
        icon = Icons.timer_outlined;
        break;
      default:
        color = Colors.grey;
        icon = Icons.notifications_none;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        notify.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        notify.timeAgo,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                    Text(
                      notify.message,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, Alert alert) {
    Color color;
    IconData icon;

    switch (alert.type) {
      case 'warning':
        color = Colors.orange;
        icon = Icons.warning_amber;
        break;
      case 'class_update':
        color = Colors.blue;
        icon = Icons.school;
        break;
      default:
        color = Colors.indigo;
        icon = Icons.campaign;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        alert.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
