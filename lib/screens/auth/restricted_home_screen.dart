// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../providers/feature_flag_provider.dart';
import '../gallery_screen.dart';
import '../kejani/kejani_tab.dart';
import '../schedule/campus_map_widget.dart';
import '../school_info_screen.dart';
import '../guest_home_screen.dart' show CampusLegendTab;

/// Limited shell shown to accounts that admins have marked `restricted`.
/// Public content only, plus a persistent banner and a sign-out action.
class RestrictedHomeScreen extends StatefulWidget {
  const RestrictedHomeScreen({super.key});

  @override
  State<RestrictedHomeScreen> createState() => _RestrictedHomeScreenState();
}

class _RestrictedTab {
  const _RestrictedTab(this.flag, this.tab, this.body);
  final String flag;
  final Tab tab;
  final Widget body;
}

class _RestrictedHomeScreenState extends State<RestrictedHomeScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late List<_RestrictedTab> _tabs;

  static const List<_RestrictedTab> _baseTabs = [
    _RestrictedTab(
      'campus_map',
      Tab(icon: Icon(Icons.map), text: 'Map'),
      CampusMapWidget(),
    ),
    _RestrictedTab(
      'legend',
      Tab(icon: Icon(Icons.layers), text: 'Legend'),
      CampusLegendTab(),
    ),
    _RestrictedTab(
      'gallery',
      Tab(icon: Icon(Icons.photo_library), text: 'Gallery'),
      GalleryScreen(),
    ),
    _RestrictedTab(
      'kejani',
      Tab(icon: Icon(Icons.apartment), text: 'Kejani'),
      KejaniTab(),
    ),
    _RestrictedTab(
      'about',
      Tab(icon: Icon(Icons.info), text: 'About'),
      SchoolInfoScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = _baseTabs;
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<_RestrictedTab> _buildTabs(FeatureFlagProvider flags) {
    final tabs = <_RestrictedTab>[
      for (final t in _baseTabs)
        if ((t.flag == 'gallery' && flags.isEnabled('gallery')) ||
            (t.flag == 'kejani' && flags.isEnabled('kejani')) ||
            (t.flag == 'campus_map' && flags.isEnabled('campus_map')) ||
            t.flag == 'legend' ||
            t.flag == 'about')
          t,
    ];
    if (tabs.isEmpty) tabs.add(_baseTabs.last);
    return tabs;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final flags = context.watch<FeatureFlagProvider>();
    final next = _buildTabs(flags);
    if (next.length != _tabs.length ||
        !List.generate(
          _tabs.length,
          (i) => i < next.length && _tabs[i].flag == next[i].flag,
          growable: false,
        ).every((same) => same)) {
      _tabs = next;
      _tabController.dispose();
      _tabController = TabController(length: _tabs.length, vsync: this);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
        appBar: AppBar(
          title: const Text('KNP - Restricted Mode'),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out'),
              onPressed: () => context.read<AuthProvider>().logout(),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: _tabs.length > 4,
            tabs: [for (final t in _tabs) t.tab],
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      auth.blockMessage ??
                          'Your account is restricted. Contact the administration.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [for (final t in _tabs) t.body],
              ),
            ),
          ],
        ),
    );
  }
}