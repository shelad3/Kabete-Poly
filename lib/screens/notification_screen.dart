import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ticket.dart';
import '../models/class_notification.dart';
import '../services/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/class_provider.dart';
import '../services/unread_badge_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/shimmer_loading.dart';

class NotificationScreen extends StatefulWidget {
  NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    // Mark read when switching to either tab
    _markAllRead();
  }

  void _markAllRead() {
    final badge = context.read<UnreadBadgeProvider>();
    badge.markNotificationsSeen([]);
    badge.resetAlertCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Notification Center'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Notifications'),
            Tab(text: 'Alerts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildNotificationsTab(),
          _buildAlertsTab(),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return Consumer2<AuthProvider, ClassProvider>(
      builder: (context, authProvider, classProvider, _) {
        return StreamBuilder<List<ClassNotification>>(
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
              return const Center(child: Text('No notifications.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final notify = notifications[index];
                return _buildNotificationCard(context, notify);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAlertsTab() {
    return Consumer2<AuthProvider, ClassProvider>(
      builder: (context, authProvider, classProvider, _) {
        final user = authProvider.currentUser;
        final regNo = user?.registrationNumber ?? '';
        final userId = authProvider.currentUserId;

        if (user == null || userId.isEmpty) {
          return const Center(child: Text('Sign in to view alerts.'));
        }

        return StreamBuilder<List<Alert>>(
          stream: _firestoreService.getAlertsForUser(userId, regNo, user.enrolledClasses),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const ShimmerNotificationList();
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final alerts = snapshot.data ?? [];
            if (alerts.isEmpty) {
              return const Center(child: Text('No alerts.'));
            }

            // Mark all as read on first load
            WidgetsBinding.instance.addPostFrameCallback((_) => _markAllRead());

            // Manually mark each alert as read in Firestore
            for (final alert in alerts) {
              if (!alert.readBy.contains(userId)) {
                _firestoreService.markAlertRead(alert.id, userId);
              }
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: alerts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return _buildAlertCard(context, alert);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(BuildContext context, ClassNotification notify) {
    Color color;
    IconData icon;

    switch (notify.type) {
      case 'canceled':
        color = Colors.red;
        icon = Icons.cancel_outlined;
      case 'event':
        color = Colors.blue;
        icon = Icons.event;
      case 'deadline':
        color = Colors.orange;
        icon = Icons.timer_outlined;
      default:
        color = Colors.grey;
        icon = Icons.notifications_none;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(notify.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Text(notify.timeAgo,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(notify.message,
                      maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.3, fontSize: 13)),
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
      case 'class_update':
        color = Colors.blue;
        icon = Icons.school;
      default:
        color = Colors.indigo;
        icon = Icons.campaign;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(alert.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(alert.message,
                      maxLines: 4, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.3, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
