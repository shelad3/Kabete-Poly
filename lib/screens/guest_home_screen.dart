import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import 'gallery_screen.dart';
import 'schedule/campus_map_widget.dart';
import 'school_info_screen.dart';
import '../widgets/guest_houses_widget.dart';

class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
        title: const Text('KNP - Guest Mode'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Login'),
            onPressed: () {
              context.read<AuthProvider>().exitGuestMode();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.map), text: 'Map'),
            Tab(icon: Icon(Icons.layers), text: 'Legend'),
            Tab(icon: Icon(Icons.photo_library), text: 'Gallery'),
            Tab(icon: Icon(Icons.home_work), text: 'Houses'),
            Tab(icon: Icon(Icons.info), text: 'About'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          CampusMapWidget(),
          CampusLegendTab(),
          GalleryScreen(),
          GuestHousesWidget(),
          SchoolInfoScreen(),
        ],
      ),
    );
  }
}

class CampusLegendTab extends StatelessWidget {
  const CampusLegendTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Switch to Map tab and tap the layers button to view legend'));
  }
}
