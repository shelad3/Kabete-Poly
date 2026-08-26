// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import '../../models/cube.dart';
import '../../services/cube_service.dart';

class ManageCubesScreen extends StatefulWidget {
  final String houseId;
  final String houseName;
  const ManageCubesScreen({
    super.key,
    required this.houseId,
    required this.houseName,
  });

  @override
  State<ManageCubesScreen> createState() => _ManageCubesScreenState();
}

class _ManageCubesScreenState extends State<ManageCubesScreen> {
  final CubeService _service = CubeService();

  Future<void> _editCube(Cube cube) async {
    final capCtrl = TextEditingController(text: cube.maxOccupancy.toString());
    String? side = cube.side;
    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text('Edit ${cube.label}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: capCtrl,
                decoration: const InputDecoration(
                  labelText: 'Max Occupancy',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: side,
                decoration: const InputDecoration(
                  labelText: 'Side (optional)',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('None')),
                  DropdownMenuItem(value: 'left', child: Text('Left')),
                  DropdownMenuItem(value: 'right', child: Text('Right')),
                ],
                onChanged: (v) => setDState(() => side = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final cap =
                    int.tryParse(capCtrl.text.trim()) ?? cube.maxOccupancy;
                await _service.updateCube(
                  cube.id,
                  Cube(
                    id: cube.id,
                    houseId: cube.houseId,
                    houseName: cube.houseName,
                    cubeNumber: cube.cubeNumber,
                    maxOccupancy: cap,
                    side: side,
                    isActive: cube.isActive,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.houseName} Cubes')),
      body: StreamBuilder<List<Cube>>(
        stream: _service.getCubesByHouseStream(widget.houseId),
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
                  Icon(
                    Icons.workspaces_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No cubes in this house',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
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
              final sideLabel = c.side != null
                  ? ' • ${c.side!.toUpperCase()} side'
                  : '';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Text(
                      '${c.cubeNumber}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    c.label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Max ${c.maxOccupancy} students$sideLabel'),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.edit,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () => _editCube(c),
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
