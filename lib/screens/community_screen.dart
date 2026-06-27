import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/unread_badge_provider.dart';
import 'forum_screen.dart';
import 'gallery_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
    final badge = context.watch<UnreadBadgeProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Badge(
                isLabelVisible: badge.unreadForum > 0,
                label: Text(
                  badge.unreadForum > 99 ? '99+' : badge.unreadForum.toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                child: const Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.forum_outlined),
                  SizedBox(height: 4),
                  Text('Forums'),
                ]),
              ),
            ),
            const Tab(icon: Icon(Icons.photo_library_outlined), text: 'Gallery'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ForumScreen(),
          GalleryScreen(),
        ],
      ),
    );
  }
}
