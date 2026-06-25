import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';

class SchoolInfoScreen extends StatefulWidget {
  const SchoolInfoScreen({super.key});

  @override
  State<SchoolInfoScreen> createState() => _SchoolInfoScreenState();
}

class _SchoolInfoScreenState extends State<SchoolInfoScreen> {
  final _nameCtrl = TextEditingController();
  final _historyCtrl = TextEditingController();
  final _photoUrlCtrl = TextEditingController();
  bool _isEditing = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _historyCtrl.dispose();
    _photoUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.read<AuthProvider>().currentUser?.isAdmin == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About KNP'),
        actions: [
          if (canEdit)
            IconButton(
              icon: Icon(_isEditing ? Icons.save : Icons.edit),
              onPressed: _isEditing ? _saveInfo : _startEditing,
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('school_info').doc('knp').snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>?;
          final schoolName = data?['name'] as String? ?? 'Kabete National Polytechnique';
          final history = data?['history'] as String? ?? _defaultHistory();
          final photoUrls = (data?['photoUrls'] as List<dynamic>?)?.cast<String>() ?? [];

          if (_isEditing) {
            _nameCtrl.text = schoolName;
            _historyCtrl.text = history;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEditing) ...[
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'School Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _historyCtrl,
                    maxLines: 10,
                    decoration: const InputDecoration(labelText: 'History & Description', border: OutlineInputBorder(), alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _photoUrlCtrl,
                    decoration: const InputDecoration(labelText: 'Add Photo URL', border: OutlineInputBorder(), hintText: 'https://...'),
                  ),
                  const SizedBox(height: 8),
                  if (_photoUrlCtrl.text.isNotEmpty && canEdit)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate, size: 18),
                      label: const Text('Add Photo'),
                      onPressed: () {
                        final url = _photoUrlCtrl.text.trim();
                        if (url.isNotEmpty) {
                          FirebaseFirestore.instance.collection('school_info').doc('knp').update({
                            'photoUrls': FieldValue.arrayUnion([url]),
                          });
                          _photoUrlCtrl.clear();
                        }
                      },
                    ),
                  const SizedBox(height: 16),
                  if (_saving) const LinearProgressIndicator(),
                ] else ...[
                  Text(schoolName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (photoUrls.isNotEmpty) ...[
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: photoUrls.length + (_isEditing ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < photoUrls.length) {
                            return Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(photoUrls[index], height: 200, width: 300, fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(height: 200, width: 300,
                                        color: Colors.grey[200], child: const Icon(Icons.broken_image, size: 48))),
                                  ),
                                ),
                                if (canEdit)
                                  Positioned(
                                    top: 4, right: 16,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.red,
                                      radius: 14,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, size: 14, color: Colors.white),
                                        padding: EdgeInsets.zero,
                                        onPressed: () {
                                          FirebaseFirestore.instance.collection('school_info').doc('knp').update({
                                            'photoUrls': FieldValue.arrayRemove([photoUrls[index]]),
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(history, style: const TextStyle(fontSize: 15, height: 1.6)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _startEditing() {
    setState(() => _isEditing = true);
  }

  Future<void> _saveInfo() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('school_info').doc('knp').set({
        'name': _nameCtrl.text.trim(),
        'history': _historyCtrl.text.trim(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('School info updated'), backgroundColor: Colors.green),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _defaultHistory() {
    return 'Kabete National Polytechnique (KNP) is a leading technical and vocational training institution '
        'located in Kabete, Nairobi, Kenya. The institution offers a wide range of diploma and certificate '
        'programs in engineering, ICT, business, and applied sciences. '
        '\n\n'
        'With a rich history spanning several decades, KNP has produced thousands of skilled graduates '
        'who have gone on to excel in various fields locally and internationally. '
        'The institution is committed to providing quality technical education and training, '
        'equipping students with practical skills for the job market.';
  }
}
