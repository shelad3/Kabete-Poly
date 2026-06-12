import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageTimetableScreen extends StatefulWidget {
  final String className;
  const ManageTimetableScreen({super.key, required this.className});

  @override
  State<ManageTimetableScreen> createState() => _ManageTimetableScreenState();
}

class _ManageTimetableScreenState extends State<ManageTimetableScreen> {
  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  CollectionReference get _timetableRef =>
      FirebaseFirestore.instance.collection('classes').doc(widget.className).collection('timetable');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add entry',
            onPressed: () => _showEntryForm(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _timetableRef.orderBy('day').orderBy('time').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data!.docs;
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No timetable entries yet', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Entry'),
                    onPressed: () => _showEntryForm(context),
                  ),
                ],
              ),
            );
          }

          final grouped = <String, List<QueryDocumentSnapshot>>{};
          for (final e in entries) {
            final day = e['day'] as String? ?? 'Unknown';
            grouped.putIfAbsent(day, () => []).add(e);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final day in _days)
                if (grouped.containsKey(day)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
                    child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey)),
                  ),
                  for (final entry in grouped[day]!)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Container(
                          width: 4, height: 48,
                          decoration: BoxDecoration(
                            color: Color(entry['color'] as int? ?? 0xFF1565C0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        title: Text(entry['unit'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${entry['time'] ?? ''}  •  ${entry['room'] ?? ''}  •  ${entry['lecturer'] ?? ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => _deleteEntry(entry.id),
                        ),
                      ),
                    ),
                ],
            ],
          );
        },
      ),
    );
  }

  void _showEntryForm(BuildContext context) {
    final timeCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    final lecturerCtrl = TextEditingController();
    String selectedDay = _days[0];
    Color selectedColor = Colors.blue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  const Text('Add Timetable Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedDay,
                    decoration: const InputDecoration(labelText: 'Day', prefixIcon: Icon(Icons.calendar_today)),
                    items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setSheetState(() => selectedDay = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: 'Time (e.g. 0800-1000 hrs)', prefixIcon: Icon(Icons.access_time))),
                  const SizedBox(height: 12),
                  TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Unit Name', prefixIcon: Icon(Icons.book))),
                  const SizedBox(height: 12),
                  TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Room', prefixIcon: Icon(Icons.location_on))),
                  const SizedBox(height: 12),
                  TextField(controller: lecturerCtrl, decoration: const InputDecoration(labelText: 'Lecturer', prefixIcon: Icon(Icons.person))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final c in [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal, Colors.indigo, Colors.pink])
                        GestureDetector(
                          onTap: () => setSheetState(() => selectedColor = c),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: selectedColor == c ? Border.all(color: Colors.black, width: 2) : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (unitCtrl.text.trim().isEmpty || timeCtrl.text.trim().isEmpty) return;
                      await _timetableRef.add({
                        'day': selectedDay,
                        'time': timeCtrl.text.trim(),
                        'unit': unitCtrl.text.trim(),
                        'room': roomCtrl.text.trim(),
                        'lecturer': lecturerCtrl.text.trim(),
                        'color': selectedColor.value,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Add Entry'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEntry(String entryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this timetable entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white)),
        ],
      ),
    );
    if (confirm == true) {
      await _timetableRef.doc(entryId).delete();
    }
  }
}
