// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/update_service.dart';
import '../providers/feature_flag_provider.dart';
import 'gallery_screen.dart';
import 'kejani/kejani_tab.dart';
import 'schedule/campus_map_widget.dart';
import 'school_info_screen.dart';
import '../widgets/guest_houses_widget.dart';

class GuestHomeScreen extends StatelessWidget {
  const GuestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flags = context.watch<FeatureFlagProvider>();
    final role = context.watch<AuthProvider>().currentUser?.role;
    final specs = <_GuestTab>[
      const _GuestTab(
        'campus_map',
        Tab(icon: Icon(Icons.map), text: 'Map'),
        CampusMapWidget(),
      ),
      const _GuestTab(
        'legend',
        Tab(icon: Icon(Icons.layers), text: 'Legend'),
        CampusLegendTab(),
      ),
      if (flags.isEnabledFor('gallery', role))
        const _GuestTab(
          'gallery',
          Tab(icon: Icon(Icons.photo_library), text: 'Gallery'),
          GalleryScreen(),
        ),
      const _GuestTab(
        'houses',
        Tab(icon: Icon(Icons.home_work), text: 'Houses'),
        GuestHousesWidget(),
      ),
      if (flags.isEnabledFor('kejani', role))
        const _GuestTab(
          'kejani',
          Tab(icon: Icon(Icons.apartment), text: 'Kejani'),
          KejaniTab(),
        ),
      const _GuestTab(
        'about',
        Tab(icon: Icon(Icons.info), text: 'About'),
        SchoolInfoScreen(),
      ),
    ];
    return _GuestTabs(
      key: ValueKey(specs.map((t) => t.flag).join('|')),
      tabs: specs,
    );
  }
}

class _GuestTab {
  const _GuestTab(this.flag, this.tab, this.body);
  final String flag;
  final Tab tab;
  final Widget body;
}

class _GuestTabs extends StatefulWidget {
  const _GuestTabs({super.key, required this.tabs});
  final List<_GuestTab> tabs;

  @override
  State<_GuestTabs> createState() => _GuestTabsState();
}

class _GuestTabsState extends State<_GuestTabs>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.tabs.length, vsync: this);
  }

  @override
  void didUpdateWidget(covariant _GuestTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabs.length == oldWidget.tabs.length) return;
    _tabController.dispose();
    _tabController = TabController(length: widget.tabs.length, vsync: this);
    if (_tabController.index >= widget.tabs.length) {
      _tabController.index = widget.tabs.length - 1;
    }
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
            icon: const Icon(Icons.system_update, size: 18),
            label: const Text('Update'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checking latest release...')),
              );
              UpdateService.checkForUpdates(context, showNoUpdateMsg: true);
            },
          ),
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
          tabs: [for (final t in widget.tabs) t.tab],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [for (final t in widget.tabs) t.body],
      ),
    );
  }
}

class CampusLegendTab extends StatelessWidget {
  const CampusLegendTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Switch to the Map tab and tap the layers button to view the legend',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}