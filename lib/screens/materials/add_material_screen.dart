// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/teaching_material.dart';
import '../../services/teaching_materials_service.dart';
import '../../services/storage_service.dart';
import '../../services/auth_provider.dart';
import '../../services/class_provider.dart';

class AddMaterialScreen extends StatefulWidget {
  const AddMaterialScreen({super.key});

  @override
  State<AddMaterialScreen> createState() => _AddMaterialScreenState();
}

class _AddMaterialScreenState extends State<AddMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final TeachingMaterialsService _service = TeachingMaterialsService();
  final StorageService _storageService = StorageService();

  File? _file;
  String? _fileName;
  String _type = 'notes';
  String _level = 'LEVEL 6';
  bool _saveForClass = true;
  bool _isUploading = false;

  static const _levels = ['LEVEL 4', 'LEVEL 5', 'LEVEL 6', 'All Levels'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.path == null) return;
    setState(() {
      _file = File(file.path!);
      _fileName = file.name;
      if (_titleCtrl.text.isEmpty) {
        _titleCtrl.text = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      }
    });
  }

  Future<void> _handleUpload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a file to upload')),
      );
      return;
    }
    setState(() => _isUploading = true);
    try {
      final auth = context.read<AuthProvider>();
      final classProvider = context.read<ClassProvider>();
      final ext = _fileName!.split('.').last.toLowerCase();

      final path =
          'materials/$ext/${DateTime.now().millisecondsSinceEpoch}_$_fileName';
      final url = await _storageService.uploadFile(_file!, path);
      if (url == null || url.isEmpty) {
        throw Exception('Upload failed');
      }

      final material = TeachingMaterial(
        id: '',
        title: _titleCtrl.text.trim(),
        subject: _subjectCtrl.text.trim().isEmpty
            ? 'General'
            : _subjectCtrl.text.trim(),
        level: _level,
        classId: _saveForClass ? classProvider.currentClass : null,
        type: _type,
        fileUrl: url,
        fileName: _fileName!,
        fileType: ext,
        fileSize: await _file!.length(),
        description: _descriptionCtrl.text.trim(),
        uploadedBy: auth.currentUserId,
        uploadedAt: DateTime.now(),
      );
      await _service.addMaterial(material);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Material published to the library'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classProvider = context.read<ClassProvider>();
    final currentClass = classProvider.currentClass;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Material')),
      body: _isUploading
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Uploading to Cloudinary...')]))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  InkWell(
                    onTap: _pickFile,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _file == null
                                ? Icons.upload_file
                                : Icons.picture_as_pdf,
                            size: 40,
                            color: scheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _fileName ?? 'Tap to choose a PDF, DOC, PPT or XLS',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subjectCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      hintText: 'e.g. Analogue Electronics',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.menu_book),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _level,
                          decoration: const InputDecoration(
                            labelText: 'Level',
                            border: OutlineInputBorder(),
                          ),
                          items: _levels
                              .map(
                                (l) => DropdownMenuItem(
                                  value: l,
                                  child: Text(l),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _level = v ?? 'LEVEL 6'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _type,
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder(),
                          ),
                          items: TeachingMaterialsService.kTypeLabels.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _type = v ?? 'notes'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Attach to my class'),
                    subtitle: Text(
                      currentClass.isEmpty
                          ? 'No class selected — visible to everyone'
                          : currentClass,
                    ),
                    value: _saveForClass,
                    onChanged: (v) => setState(() => _saveForClass = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _handleUpload,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Publish to Library'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}