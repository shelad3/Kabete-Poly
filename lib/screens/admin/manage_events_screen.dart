import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;

class ManageEventsScreen extends StatefulWidget {
  const ManageEventsScreen({super.key});

  @override
  State<ManageEventsScreen> createState() => _ManageEventsScreenState();
}

class _ManageEventsScreenState extends State<ManageEventsScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _eventDate = DateTime.now();
  String _visibility = 'public';
  final List<Map<String, String>> _specialGuests = [];
  final List<XFile> _selectedPhotos = [];
  bool _isUploading = false;

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
                decoration: const InputDecoration(labelText: 'Role (e.g. HOD, Principal)', border: OutlineInputBorder())),
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
      final eventRef = FirebaseFirestore.instance.collection('events').doc();

      String coverUrl = '';
      int photoCount = 0;

      if (_selectedPhotos.isNotEmpty) {
        // Upload cover photo
        final coverFile = _selectedPhotos.first;
        final coverExt = coverFile.name.split('.').last;
        final coverRef = FirebaseStorage.instance.ref('events/${eventRef.id}/cover.$coverExt');
        await coverRef.putData(await coverFile.readAsBytes());
        coverUrl = await coverRef.getDownloadURL();
        photoCount = _selectedPhotos.length;

        // Upload remaining photos to subcollection
        final batch = FirebaseFirestore.instance.batch();
        for (int i = 1; i < _selectedPhotos.length; i++) {
          final photo = _selectedPhotos[i];
          final ext = photo.name.split('.').last;
          final photoRef = FirebaseStorage.instance.ref('events/${eventRef.id}/photos/photo_$i.$ext');
          await photoRef.putData(await photo.readAsBytes());
          final url = await photoRef.getDownloadURL();

          final photoDocRef = eventRef.collection('photos').doc();
          batch.set(photoDocRef, {
            'url': url,
            'caption': '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      // Set event doc
      await eventRef.set({
        'title': title,
        'description': _descController.text.trim(),
        'date': Timestamp.fromDate(_eventDate),
        'visibility': _visibility,
        'coverUrl': coverUrl,
        'photoCount': photoCount,
        'specialGuests': _specialGuests,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create event: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event Gallery')),
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
            // Photos
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
                              width: 100,
                              height: 100,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      ),
                      if (i == 0)
                        Positioned(
                          top: 4,
                          left: 4,
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
            // Special Guests
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
                label: Text(_isUploading ? 'Uploading...' : 'Create Event Gallery'),
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


