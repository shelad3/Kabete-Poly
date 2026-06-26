import 'package:flutter/material.dart';
import '../../models/cube.dart' as model;
import '../../services/cube_service.dart';

class ManageCubesScreen extends StatefulWidget {
  const ManageCubesScreen({super.key});

  @override
  State<ManageCubesScreen> createState() => _ManageCubesScreenState();
}

class _ManageCubesScreenState extends State<ManageCubesScreen> {
  final CubeService _service = CubeService();
  final _houseCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _houseCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    _houseCtrl.clear();
    _labelCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Cubicle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _houseCtrl,
              decoration: const InputDecoration(labelText: 'House / Lab Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(labelText: 'Cubicle Label (e.g. C01)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_houseCtrl.text.trim().isEmpty || _labelCtrl.text.trim().isEmpty) return;
              await _service.addCube(model.Cube(
                id: '',
                houseName: _houseCtrl.text.trim(),
                label: _labelCtrl.text.trim().toUpperCase(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCube(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Cubicle'),
        content: const Text('Deactivate this cubicle? Bookings will be preserved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deleteCube(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Cubicles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDialog,
            tooltip: 'Add Cubicle',
          ),
        ],
      ),
      body: StreamBuilder<List<model.Cube>>(
        stream: _service.getCubesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final cubes = snapshot.data ?? [];
          if (cubes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspaces_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No cubicles configured', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Cubicle'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: cubes.length,
            itemBuilder: (_, i) {
              final c = cubes[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    child: Icon(Icons.workspaces, color: Colors.blue[400]),
                  ),
                  title: Text('${c.label} — ${c.houseName}'),
                  subtitle: Text(c.isActive ? 'Active' : 'Inactive'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteCube(c.id),
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
