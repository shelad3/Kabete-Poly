import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../services/storage_service.dart';

class ManageEventsScreen extends StatefulWidget {
  const ManageEventsScreen({super.key});

  @override
  State<ManageEventsScreen> createState() => _ManageEventsScreenState();
}

class _ManageEventsScreenState extends State<ManageEventsScreen> {
  void _deleteEvent(DocumentSnapshot doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Delete "${doc['title']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final photos = await doc.reference.collection('photos').get();
        for (final p in photos.docs) {
          await p.reference.delete();
        }
        await doc.reference.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Events')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('events').orderBy('date', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data?.docs ?? [];
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No events yet', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showEventForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Event'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: events.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton.icon(
                    onPressed: () => _showEventForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Event'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                );
              }
              final doc = events[i - 1];
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: data['coverUrl'] != null && (data['coverUrl'] as String).isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(data['coverUrl'], width: 48, height: 48, fit: BoxFit.cover),
                        )
                      : CircleAvatar(child: Icon(Icons.image, color: Colors.grey[400])),
                  title: Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${DateFormat('d MMM yyyy').format((data['date'] as Timestamp).toDate())} • ${data['visibility'] ?? 'public'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showEventForm(existingDoc: doc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _deleteEvent(doc),
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

  void _showEventForm({DocumentSnapshot? existingDoc}) {
    final existingData = existingDoc?.data() as Map<String, dynamic>?;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EventFormScreen(
          existingDoc: existingDoc,
          existingData: existingData,
        ),
      ),
    );
  }
}

class _EventFormScreen extends StatefulWidget {
  final DocumentSnapshot? existingDoc;
  final Map<String, dynamic>? existingData;
  const _EventFormScreen({this.existingDoc, this.existingData});

  @override
  State<_EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<_EventFormScreen> {
  final StorageService _storage = StorageService();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  late DateTime _eventDate;
  String _visibility = 'public';
  List<Map<String, String>> _specialGuests = [];
  final List<XFile> _selectedPhotos = [];
  bool _isUploading = false;
  bool get _isEdit => widget.existingDoc != null;

  @override
  void initState() {
    super.initState();
    final data = widget.existingData;
    if (data != null) {
      _titleController.text = data['title'] ?? '';
      _descController.text = data['description'] ?? '';
      _eventDate = (data['date'] as Timestamp).toDate();
      _visibility = data['visibility'] ?? 'public';
      final guests = data['specialGuests'] as List<dynamic>?;
      if (guests != null) {
        _specialGuests = guests.map((g) => Map<String, String>.from(g as Map)).toList();
      }
    } else {
      _eventDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  void _pickPhotos() async {
    final picker = ImagePicker();
    final photos = await picker.pickMultiImage();
    if (photos.isNotEmpty) {
      setState(() => _selectedPhotos.addAll(photos));
    }
  }

  void _addGuest() {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final photoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Special Guest'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Role (e.g. HOD, Principal)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: photoCtrl,
                decoration: const InputDecoration(labelText: 'Photo URL (optional)', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                setState(() => _specialGuests.add({
                      'name': nameCtrl.text.trim(),
                      'role': roleCtrl.text.trim(),
                      'photoUrl': photoCtrl.text.trim(),
                    }));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveEvent() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event title is required'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isUploading = true);

    try {
      final db = FirebaseFirestore.instance;
      final eventRef = _isEdit
          ? widget.existingDoc!.reference
          : db.collection('events').doc();

      String coverUrl = widget.existingData?['coverUrl'] ?? '';
      int photoCount = _selectedPhotos.length;

      if (_selectedPhotos.isNotEmpty) {
        final eventId = eventRef.id;
        final coverFile = File(_selectedPhotos.first.path);
        final coverUploaded = await _storage.uploadImage(coverFile, 'events/$eventId/cover');
        if (coverUploaded != null) coverUrl = coverUploaded;

        final batch = db.batch();
        for (int i = 1; i < _selectedPhotos.length; i++) {
          final photo = File(_selectedPhotos[i].path);
          final url = await _storage.uploadImage(photo, 'events/$eventId/photo_$i');
          if (url != null) {
            final photoDocRef = eventRef.collection('photos').doc();
            batch.set(photoDocRef, {
              'url': url,
              'caption': '',
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
        await batch.commit();
      } else if (!_isEdit) {
        photoCount = 0;
      }

      await eventRef.set({
        'title': title,
        'description': _descController.text.trim(),
        'date': Timestamp.fromDate(_eventDate),
        'visibility': _visibility,
        'coverUrl': coverUrl,
        'photoCount': photoCount,
        'specialGuests': _specialGuests,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Event updated!' : 'Event created!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save event: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Event' : 'Create Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Event Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('d MMM yyyy').format(_eventDate)),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _visibility,
                  items: const [
                    DropdownMenuItem(value: 'public', child: Text('Public')),
                    DropdownMenuItem(value: 'private', child: Text('Private')),
                  ],
                  onChanged: (v) => setState(() => _visibility = v!),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Photos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickPhotos,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text('${_selectedPhotos.length} selected'),
                ),
              ],
            ),
            if (_selectedPhotos.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedPhotos.length,
                  itemBuilder: (_, i) => Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_selectedPhotos[i].path),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100, height: 100,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      ),
                      if (i == 0)
                        Positioned(
                          top: 4, left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              Container(
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('No photos selected (optional)', style: TextStyle(color: Colors.grey[500])),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Special Guests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addGuest,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add'),
                ),
              ],
            ),
            ..._specialGuests.map((g) => ListTile(
                  leading: CircleAvatar(child: Text((g['name']?[0] ?? '?').toUpperCase())),
                  title: Text(g['name'] ?? ''),
                  subtitle: g['role']?.isNotEmpty == true ? Text(g['role']!) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _specialGuests.remove(g)),
                  ),
                )),
            if (_specialGuests.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('No special guests added', style: TextStyle(color: Colors.grey[500])),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _saveEvent,
                icon: _isUploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload),
                label: Text(_isUploading
                    ? 'Uploading...'
                    : (_isEdit ? 'Update Event' : 'Create Event Gallery')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
