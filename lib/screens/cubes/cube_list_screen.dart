import 'package:flutter/material.dart';
import '../../models/house.dart';
import '../../models/cube.dart';
import '../../services/cube_service.dart';
import '../../utils/term_utils.dart';
import 'booking_form_screen.dart';

class CubeListScreen extends StatefulWidget {
  final House house;
  const CubeListScreen({super.key, required this.house});

  @override
  State<CubeListScreen> createState() => _CubeListScreenState();
}

class _CubeListScreenState extends State<CubeListScreen> {
  final CubeService _service = CubeService();
  final int _term = TermUtils.getCurrentTerm();
  final int _year = TermUtils.getCurrentYear();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.house.name)),
      body: StreamBuilder<List<Cube>>(
        stream: _service.getCubesByHouseStream(widget.house.id),
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
                  Text('No cubes in this house yet',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            );
          }
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey[50],
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${TermUtils.getCurrentTermLabel()} ${TermUtils.getCurrentYear()} — KSH 8,000 per term',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
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
                    service: _service,
                    term: _term,
                    year: _year,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingFormScreen(
                          cube: cubes[i],
                          house: widget.house,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CubeTile extends StatefulWidget {
  final Cube cube;
  final CubeService service;
  final int term;
  final int year;
  final VoidCallback onTap;

  const _CubeTile({
    required this.cube,
    required this.service,
    required this.term,
    required this.year,
    required this.onTap,
  });

  @override
  State<_CubeTile> createState() => _CubeTileState();
}

class _CubeTileState extends State<_CubeTile> {
  int _available = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final available = await widget.service.getAvailableSpots(
      widget.cube.id, widget.cube.maxOccupancy, widget.term, widget.year,
    );
    if (mounted) {
      setState(() {
        _available = available;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final full = !_loading && _available <= 0;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: full ? Colors.grey[200] : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: full ? null : widget.onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              full ? Icons.workspaces : Icons.workspaces,
              size: 28,
              color: full ? Colors.grey[400] : Colors.blue[400],
            ),
            const SizedBox(height: 4),
            Text(widget.cube.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            if (_loading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else if (full)
              Text('Full', style: TextStyle(color: Colors.red[400], fontSize: 10, fontWeight: FontWeight.w600))
            else
              Text('$_available spots', style: TextStyle(color: Colors.green[600], fontSize: 10)),
            Text('Max ${widget.cube.maxOccupancy}', style: TextStyle(color: Colors.grey[500], fontSize: 9)),
          ],
        ),
      ),
    );
  }
}
