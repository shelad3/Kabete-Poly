import 'package:flutter/material.dart';
import '../../services/lesson_verification_service.dart';

class LessonVerificationScreen extends StatefulWidget {
  const LessonVerificationScreen({super.key});

  @override
  State<LessonVerificationScreen> createState() => _LessonVerificationScreenState();
}

class _LessonVerificationScreenState extends State<LessonVerificationScreen> {
  final _service = LessonVerificationService();
  String _departmentFilter = 'All';
  final List<String> _departments = ['All', 'ICT', 'Engineering', 'Business', 'Applied Sciences', 'General'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lesson Verification')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                const Text('Filter by Department: ', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _departmentFilter,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setState(() => _departmentFilter = v ?? 'All'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _service.allVerificationsStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.how_to_vote, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No lesson verifications yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        SizedBox(height: 8),
                        Text('Students vote during live lessons', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final filtered = docs.where((doc) {
                  if (_departmentFilter == 'All') return true;
                  final classId = (doc.data() as Map<String, dynamic>)['classId'] as String? ?? '';
                  return classId.toLowerCase().contains(_departmentFilter.toLowerCase());
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text('No verifications for $_departmentFilter',
                        style: const TextStyle(color: Colors.grey, fontSize: 16)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final data = filtered[index].data() as Map<String, dynamic>;
                    final classId = data['classId'] ?? '';
                    final subject = data['subject'] ?? '';
                    final date = data['date'] ?? '';
                    final votesFor = (data['votesFor'] as List<dynamic>?)?.length ?? 0;
                    final votesAgainst = (data['votesAgainst'] as List<dynamic>?)?.length ?? 0;
                    final total = votesFor + votesAgainst;
                    final isConfirmed = data['isConfirmed'] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isConfirmed ? Icons.check_circle : Icons.schedule,
                                  color: isConfirmed ? Colors.green : Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('$subject', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isConfirmed ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isConfirmed ? 'Confirmed' : 'Pending',
                                    style: TextStyle(
                                      color: isConfirmed ? Colors.green : Colors.orange,
                                      fontSize: 12, fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('$classId  •  $date', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _voteChip(Icons.thumb_up, 'Taught: $votesFor', Colors.green),
                                const SizedBox(width: 8),
                                _voteChip(Icons.thumb_down, 'Not Taught: $votesAgainst', Colors.red),
                                const SizedBox(width: 8),
                                _voteChip(Icons.people, 'Total: $total', Colors.blue),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _voteChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
