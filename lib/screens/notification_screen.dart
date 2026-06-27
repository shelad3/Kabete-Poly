import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../models/ticket.dart';
import '../models/class_notification.dart';
import '../services/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/class_provider.dart';
import '../services/unread_badge_provider.dart';
import '../services/update_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/shimmer_loading.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabCtrl;
  PackageInfo? _packageInfo;
  Map<String, String>? _pendingUpdate;
  bool _alertsMarked = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    _packageInfo = await PackageInfo.fromPlatform();
    _pendingUpdate = await UpdateService.getPendingUpdateInfo();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    if (_tabCtrl.index == 2) {
      final badge = context.read<UnreadBadgeProvider>();
      badge.resetUpdateCount();
      UpdateService.clearPendingUpdate();
    } else if (_tabCtrl.index == 0) {
      _markRead();
    }
  }

  void _markRead() {
    final badge = context.read<UnreadBadgeProvider>();
    badge.markNotificationsSeen([]);
    badge.resetAlertCount();
  }

  @override
  Widget build(BuildContext context) {
    final badge = context.watch<UnreadBadgeProvider>();
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Notification Center'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: [
            Tab(
              child: Badge(
                isLabelVisible: badge.unreadNotifications > 0,
                label: Text(
                  badge.unreadNotifications > 99 ? '99+' : badge.unreadNotifications.toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                child: const Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.notifications_none_outlined),
                  SizedBox(height: 4),
                  Text('Notifications'),
                ]),
              ),
            ),
            Tab(
              child: Badge(
                isLabelVisible: badge.unreadAlerts > 0,
                label: Text(
                  badge.unreadAlerts > 99 ? '99+' : badge.unreadAlerts.toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                child: const Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.warning_amber_outlined),
                  SizedBox(height: 4),
                  Text('Alerts'),
                ]),
              ),
            ),
            Tab(
              child: Badge(
                isLabelVisible: badge.unreadUpdates > 0,
                label: Text(
                  badge.unreadUpdates > 99 ? '99+' : badge.unreadUpdates.toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                child: const Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.system_update_outlined),
                  SizedBox(height: 4),
                  Text('Updates'),
                ]),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildNotificationsTab(),
          _buildAlertsTab(),
          _buildUpdatesTab(),
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

            if (!_alertsMarked) {
              _alertsMarked = true;
              final badge = context.read<UnreadBadgeProvider>();
              badge.resetAlertCount();
              for (final alert in alerts) {
                if (!alert.readBy.contains(userId)) {
                  _firestoreService.markAlertRead(alert.id, userId);
                }
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

  Widget _buildUpdatesTab() {
    if (_packageInfo == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('Current Version', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('v${_packageInfo!.version}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300)),
                const SizedBox(height: 4),
                Text('Build ${_packageInfo!.buildNumber}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_pendingUpdate != null) ...[
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.system_update, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text('Update Available', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Version ${_pendingUpdate!['version']} is ready.', style: const TextStyle(fontSize: 16)),
                  if ((_pendingUpdate!['notes'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text("What's new:", style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_pendingUpdate!['notes']!, style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => UpdateService.checkForUpdates(context, showNoUpdateMsg: false),
                      icon: const Icon(Icons.download),
                      label: const Text('Install Update'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.search, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('Check for Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      UpdateService.checkForUpdates(context, showNoUpdateMsg: true).then((_) async {
                        final info = await UpdateService.getPendingUpdateInfo();
                        if (mounted) setState(() => _pendingUpdate = info);
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Check Now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
