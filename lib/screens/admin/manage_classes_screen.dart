import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/class_provider.dart';
import '../../utils/timetable_data.dart';
import 'manage_timetable_screen.dart';

class ManageClassesScreen extends StatefulWidget {
  const ManageClassesScreen({super.key});

  @override
  State<ManageClassesScreen> createState() => _ManageClassesScreenState();
}

class _ManageClassesScreenState extends State<ManageClassesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Classes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add class',
            onPressed: () => _showAddClassDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('classes').snapshots(),
        builder: (context, snapshot) {
          final firestoreClasses = snapshot.data?.docs.map((d) => d.id).toSet() ?? {};
          final hardcodedClasses = TimetableData.cohorts.keys.toSet();
          final allClasses = hardcodedClasses.union(firestoreClasses).toList()..sort();

          if (allClasses.isEmpty) {
            return const Center(child: Text('No classes found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: allClasses.length,
            itemBuilder: (context, index) {
              final className = allClasses[index];
              final isHardcoded = hardcodedClasses.contains(className);
              final isFirestore = firestoreClasses.contains(className);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isHardcoded ? Colors.blue.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                    child: Icon(
                      isHardcoded ? Icons.book : Icons.add_circle,
                      color: isHardcoded ? Colors.blue : Colors.green,
                      size: 20,
                    ),
                  ),
                  title: Text(className, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    isHardcoded && isFirestore ? 'Hardcoded + Firestore' :
                    isHardcoded ? 'Hardcoded timetable' : 'Firestore-managed',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isFirestore)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          tooltip: 'Delete class & all timetable data',
                          onPressed: () => _deleteClass(context, className),
                        ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManageTimetableScreen(className: className),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddClassDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Class'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Class/Cohort name',
            hintText: 'e.g. EIT 700 M27',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await FirebaseFirestore.instance.collection('classes').doc(name).set({
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) {
                Navigator.pop(ctx);
                context.read<ClassProvider>().refreshClasses();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClass(BuildContext context, String className) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text('This will permanently delete "$className" and all its timetable entries. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // Delete all timetable subcollection entries
    final batch = FirebaseFirestore.instance.batch();
    final timetableDocs = await FirebaseFirestore.instance
        .collection('classes')
        .doc(className)
        .collection('timetable')
        .get();
    for (final doc in timetableDocs.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(FirebaseFirestore.instance.collection('classes').doc(className));
    await batch.commit();

    if (mounted) {
      context.read<ClassProvider>().refreshClasses();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$className" deleted'), backgroundColor: Colors.green),
      );
    }
  }
}
