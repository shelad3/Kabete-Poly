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
    final cubesCtrl = TextEditingController(text: '12');
    final capacityCtrl = TextEditingController(text: '4');
    String category = 'boys';

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
                        controller: cubesCtrl,
                        decoration: const InputDecoration(labelText: 'Total Cubes', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: capacityCtrl,
                        decoration: const InputDecoration(labelText: 'Max per Cube', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
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
                if (name.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('House name is required')),
                  );
                  return;
                }
                final totalCubes = int.tryParse(cubesCtrl.text.trim()) ?? 12;
                final defaultCapacity = int.tryParse(capacityCtrl.text.trim()) ?? 4;
                try {
                  final houseId = await _houseService.addHouse(House(
                    id: '',
                    name: name,
                    category: category,
                    totalCubes: totalCubes,
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  ));
                  await _cubeService.generateCubesForHouse(houseId, name, totalCubes, defaultCapacity: defaultCapacity);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to add house: $e')),
                    );
                  }
                }
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
                          if (!context.mounted) return;
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
                            try {
                              await _houseService.deleteHouse(h.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('House deleted'), backgroundColor: Colors.green),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to delete house: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
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
