import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/house.dart';
import '../../services/house_service.dart';
import '../../services/auth_provider.dart';
import 'cube_list_screen.dart';

class HouseListScreen extends StatefulWidget {
  const HouseListScreen({super.key});

  @override
  State<HouseListScreen> createState() => _HouseListScreenState();
}

class _HouseListScreenState extends State<HouseListScreen> with TickerProviderStateMixin {
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
    final user = context.watch<AuthProvider>().currentUser;
    final isNew = user?.isNewStudent ?? true;
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
          _HouseCategoryTab(category: 'boys', isNewStudent: isNew),
          _HouseCategoryTab(category: 'girls', isNewStudent: isNew),
        ],
      ),
    );
  }
}

class _HouseCategoryTab extends StatelessWidget {
  final String category;
  final bool isNewStudent;
  const _HouseCategoryTab({required this.category, required this.isNewStudent});

  @override
  Widget build(BuildContext context) {
    final service = HouseService();
    return StreamBuilder<List<House>>(
      stream: service.getHousesByCategoryStream(category),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 8),
                Text('Error loading houses', style: TextStyle(color: Colors.red[600])),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var houses = snapshot.data ?? [];
        if (!isNewStudent) {
          houses = houses.where((h) => !h.reservedForNewStudents).toList();
        }
        if (houses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(category == 'boys' ? Icons.male : Icons.female, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(isNewStudent ? 'No $category houses configured' : 'No $category houses available',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                if (!isNewStudent)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Houses reserved for new students are hidden',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ),
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
          itemBuilder: (_, i) => _HouseCard(house: houses[i], isNewStudent: isNewStudent),
        );
      },
    );
  }
}

class _HouseCard extends StatelessWidget {
  final House house;
  final bool isNewStudent;
  const _HouseCard({required this.house, required this.isNewStudent});

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
              if (house.reservedForNewStudents)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('New Students', style: TextStyle(color: Colors.orange[700], fontSize: 9, fontWeight: FontWeight.bold)),
                ),
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
