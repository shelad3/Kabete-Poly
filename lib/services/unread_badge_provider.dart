import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/class_notification.dart';
import '../models/ticket.dart';

class UnreadBadgeProvider extends ChangeNotifier {
  int _notificationCount = 0;
  int _alertCount = 0;
  final int _forumCount = 0;

  int get totalUnread => _notificationCount + _alertCount + _forumCount;
  int get unreadNotifications => _notificationCount;
  int get unreadAlerts => _alertCount;
  int get unreadForum => _forumCount;

  StreamSubscription? _notifSub;
  StreamSubscription? _alertSub;
  Set<String> _seenNotifIds = {};
  List<String> _currentNotifIds = [];

  Future<void> init(String userId, String regNo, List<String> enrolledClasses, String? classId) async {
    final prefs = await SharedPreferences.getInstance();
    _seenNotifIds = prefs.getStringList('seen_notifications')?.toSet() ?? {};

    _notifSub = _getNotificationStream(classId).listen((notifs) {
      _currentNotifIds = notifs.map((n) => n.id).toList();
      final unseen = notifs.where((n) => !_seenNotifIds.contains(n.id)).length;
      _notificationCount = unseen;
      notifyListeners();
    });

    if (userId.isNotEmpty) {
      _alertSub = _getAlertStream(userId, regNo, enrolledClasses).listen((alerts) {
        _alertCount = alerts.length;
        notifyListeners();
      });
    }
  }

  Stream<List<ClassNotification>> _getNotificationStream(String? classId) {
    final fs = FirebaseFirestore.instance;
    Query<Map<String, dynamic>> query = fs.collection('notifications').orderBy('timestamp', descending: true);
    if (classId != null && classId.isNotEmpty && classId != 'Global / General Assembly') {
      query = query.where('classId', whereIn: [classId, 'General']);
    }
    return query.limit(50).snapshots().map((s) =>
      s.docs.map((d) => ClassNotification.fromJson(d.data(), d.id)).toList());
  }

  Stream<List<Alert>> _getAlertStream(String userId, String regNo, List<String> enrolledClasses) {
    final fs = FirebaseFirestore.instance;
    return fs.collection('alerts')
        .where('targetType', whereIn: ['all', 'user', 'class', 'regNo'])
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> s) => s.docs
          .map((d) => Alert.fromJson(d.data(), d.id))
          .where((a) =>
            a.targetType == 'all' ||
            (a.targetType == 'user' && a.targetId == userId) ||
            (a.targetType == 'regNo' && regNo.isNotEmpty && a.targetId == regNo) ||
            (a.targetType == 'class' && enrolledClasses.contains(a.targetId)))
          .where((a) => !a.readBy.contains(userId))
          .toList());
  }

  Future<void> markNotificationsSeen(List<String> ids) async {
    if (ids.isEmpty) {
      _seenNotifIds.addAll(_currentNotifIds);
    } else {
      _seenNotifIds.addAll(ids);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('seen_notifications', _seenNotifIds.toList());
    _notificationCount = 0;
    notifyListeners();
  }

  void resetAlertCount() {
    _alertCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _alertSub?.cancel();
    super.dispose();
  }
}
