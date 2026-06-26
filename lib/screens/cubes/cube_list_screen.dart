import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cube.dart' as model;
import '../../services/cube_service.dart';
import 'booking_form_screen.dart';

class CubeListScreen extends StatefulWidget {
  final String? initialRoom;
  const CubeListScreen({super.key, this.initialRoom});

  @override
  State<CubeListScreen> createState() => _CubeListScreenState();
}

class _CubeListScreenState extends State<CubeListScreen> {
  final CubeService _service = CubeService();
  List<String> _rooms = [];
  String? _selectedRoom;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final rooms = await _service.getDistinctRooms();
    if (mounted) {
      setState(() {
        _rooms = rooms;
        _selectedRoom = widget.initialRoom ?? (rooms.isNotEmpty ? rooms.first : null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book a Cubicle')),
      body: Column(
        children: [
          if (_rooms.isNotEmpty)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _rooms.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => FilterChip(
                  label: Text(_rooms[i]),
                  selected: _selectedRoom == _rooms[i],
                  onSelected: (_) => setState(() => _selectedRoom = _rooms[i]),
                ),
              ),
            ),
          if (_selectedRoom != null)
            Expanded(
              child: _buildCubeGrid(_selectedRoom!),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.workspaces_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('No cubicles available', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCubeGrid(String room) {
    return StreamBuilder<List<model.Cube>>(
      stream: _service.getCubesByRoomStream(room),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final cubes = snapshot.data ?? [];
        if (cubes.isEmpty) {
          return Center(
            child: Text('No cubicles in $room', style: TextStyle(color: Colors.grey[600])),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: cubes.length,
          itemBuilder: (_, i) => _CubeTile(
            cube: cubes[i],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingFormScreen(cube: cubes[i]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CubeTile extends StatelessWidget {
  final model.Cube cube;
  final VoidCallback onTap;

  const _CubeTile({required this.cube, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.workspaces, size: 32, color: Colors.blue[400]),
            const SizedBox(height: 6),
            Text(cube.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(cube.roomName, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
