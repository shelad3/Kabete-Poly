import 'package:flutter/material.dart';
import '../../models/house.dart';
import '../../services/house_service.dart';
import '../../services/cube_service.dart';
import 'manage_cubes_screen.dart';

class ManageHousesScreen extends StatefulWidget {
  const ManageHousesScreen({super.key});

  @override
  State<ManageHousesScreen> createState() => _ManageHousesScreenState();
}

class _ManageHousesScreenState extends State<ManageHousesScreen> {
  final HouseService _houseService = HouseService();
  final CubeService _cubeService = CubeService();

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'boys';
    int totalCubes = 12;
    int defaultCapacity = 4;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Add House'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'House Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'boys', child: Text('Boys')),
                    DropdownMenuItem(value: 'girls', child: Text('Girls')),
                  ],
                  onChanged: (v) => setDState(() => category = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Total Cubes', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(text: totalCubes.toString()),
                        onChanged: (v) => setDState(() => totalCubes = int.tryParse(v) ?? 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Max per Cube', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(text: defaultCapacity.toString()),
                        onChanged: (v) => setDState(() => defaultCapacity = int.tryParse(v) ?? 4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final houseId = await _houseService.addHouse(House(
                  id: '',
                  name: name,
                  category: category,
                  totalCubes: totalCubes,
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                ));
                await _cubeService.generateCubesForHouse(houseId, name, totalCubes, defaultCapacity: defaultCapacity);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Houses'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog, tooltip: 'Add House'),
        ],
      ),
      body: StreamBuilder<List<House>>(
        stream: _houseService.getHousesStream(),
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
                  Icon(Icons.workspaces_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No houses configured', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add First House'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: houses.length,
            itemBuilder: (_, i) {
              final h = houses[i];
              final isBoys = h.category == 'boys';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (isBoys ? Colors.blue : Colors.pink).withValues(alpha: 0.1),
                    child: Icon(isBoys ? Icons.male : Icons.female,
                        color: isBoys ? Colors.blue : Colors.pink),
                  ),
                  title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${h.category.toUpperCase()} • ${h.totalCubes} cubes'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.workspaces, color: Colors.indigo),
                        tooltip: 'Manage Cubes',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ManageCubesScreen(houseId: h.id, houseName: h.name)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete House'),
                              content: Text('Delete "${h.name}"? This will not delete cubes.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _houseService.deleteHouse(h.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
