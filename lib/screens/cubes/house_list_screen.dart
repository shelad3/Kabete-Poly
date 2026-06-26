import 'package:flutter/material.dart';
import '../../models/house.dart';
import '../../services/house_service.dart';
import 'cube_list_screen.dart';

class HouseListScreen extends StatefulWidget {
  const HouseListScreen({super.key});

  @override
  State<HouseListScreen> createState() => _HouseListScreenState();
}

class _HouseListScreenState extends State<HouseListScreen> with TickerProviderStateMixin {
  final HouseService _service = HouseService();
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
        title: const Text('Book a Cubicle'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.male), text: 'Boys Houses'),
            Tab(icon: Icon(Icons.female), text: 'Girls Houses'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _HouseCategoryTab(category: 'boys'),
          _HouseCategoryTab(category: 'girls'),
        ],
      ),
    );
  }
}

class _HouseCategoryTab extends StatelessWidget {
  final String category;
  const _HouseCategoryTab({required this.category});

  @override
  Widget build(BuildContext context) {
    final service = HouseService();
    return StreamBuilder<List<House>>(
      stream: service.getHousesByCategoryStream(category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final houses = snapshot.data ?? [];
        if (houses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(category == 'boys' ? Icons.male : Icons.female, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No $category houses configured',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16)),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: houses.length,
          itemBuilder: (_, i) => _HouseCard(house: houses[i]),
        );
      },
    );
  }
}

class _HouseCard extends StatelessWidget {
  final House house;
  const _HouseCard({required this.house});

  @override
  Widget build(BuildContext context) {
    final isBoys = house.category == 'boys';
    final color = isBoys ? Colors.blue : Colors.pink;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CubeListScreen(house: house)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isBoys ? Icons.workspaces : Icons.workspaces_outlined, size: 40, color: color),
              const SizedBox(height: 8),
              Text(house.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('${house.totalCubes} cubes', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              if (house.description != null && house.description!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(house.description!, style: TextStyle(color: Colors.grey[500], fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
