// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pdf_viewer_screen.dart';
import '../../models/teaching_material.dart';
import '../../services/teaching_materials_service.dart';
import '../../services/auth_provider.dart';
import '../../services/class_provider.dart';
import 'add_material_screen.dart';

class NotesLibraryScreen extends StatefulWidget {
  const NotesLibraryScreen({super.key});

  @override
  State<NotesLibraryScreen> createState() => _NotesLibraryScreenState();
}

class _NotesLibraryScreenState extends State<NotesLibraryScreen> {
  final TeachingMaterialsService _service = TeachingMaterialsService();
  String? _subjectFilter;
  List<String> _subjects = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  bool _canWrite(AuthProvider auth) {
    final role = auth.currentUser?.role ?? '';
    return role == 'Teacher' || role == 'Official' || role == 'Admin';
  }

  Future<void> _loadSubjects() async {
    try {
      final subjects = await _service.fetchSubjects();
      if (mounted) setState(() => _subjects = subjects);
    } catch (_) {}
  }

  void _openMaterial(TeachingMaterial m) async {
    final url = m.fileUrl;
    if (url.isEmpty) return;

    // PDFs open in the built-in reader; other files fall back to the external app.
    final isPdf = m.fileType.contains('pdf') || url.toLowerCase().endsWith('.pdf');
    if (isPdf) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(title: m.title, url: url),
        ),
      );
      return;
    }

    final uri = Uri.parse(url);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this file')),
      );
    }
  }

  IconData _extIcon(String fileType) {
    if (fileType.contains('pdf')) return Icons.picture_as_pdf;
    if (fileType.contains('word') ||
        fileType.endsWith('doc') ||
        fileType.endsWith('docx')) {
      return Icons.description;
    }
    if (fileType.contains('excel') ||
        fileType.endsWith('xls') ||
        fileType.endsWith('xlsx')) {
      return Icons.table_chart;
    }
    if (fileType.endsWith('ppt') || fileType.endsWith('pptx')) {
      return Icons.slideshow;
    }
    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes Library')),
      body: Column(
        children: [
          if (_subjects.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _subjectFilter == null,
                      onSelected: (_) =>
                          setState(() => _subjectFilter = null),
                    ),
                  ),
                  ..._subjects.map(
                    (s) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: _subjectFilter == s,
                        onSelected: (sel) =>
                            setState(() => _subjectFilter = sel ? s : null),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Consumer<ClassProvider>(
              builder: (context, classProvider, _) {
                final classId = classProvider.currentClass;
                return StreamBuilder<QuerySnapshot>(
                  stream: _service.watchAll(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }
                    final docs = snapshot.data?.docs ?? [];
                    var materials = docs
                        .map((d) => TeachingMaterial.fromFirestore(d))
                        .toList();
                    if (classId.isNotEmpty) {
                      materials = materials
                          .where(
                            (m) =>
                                m.classId == null ||
                                m.classId!.isEmpty ||
                                m.classId == classId,
                          )
                          .toList();
                    }
                    if (_subjectFilter != null) {
                      materials = materials
                          .where((m) => m.subject == _subjectFilter)
                          .toList();
                    }
                    if (materials.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            const Text('No materials yet'),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: Text(
                                classId.isEmpty
                                    ? 'Join a class to see its notes library.'
                                    : 'No notes published for ${classId.isEmpty ? 'your class' : classId} yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                      itemCount: materials.length,
                      itemBuilder: (context, index) {
                        final m = materials[index];
                        return _MaterialCard(
                          material: m,
                          icon: _extIcon(m.fileType),
                          onOpen: () => _openMaterial(m),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!_canWrite(auth)) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddMaterialScreen(),
                ),
              );
              _loadSubjects();
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload'),
          );
        },
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final TeachingMaterial material;
  final IconData icon;
  final VoidCallback onOpen;

  const _MaterialCard({
    required this.material,
    required this.icon,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final typeLabel =
        TeachingMaterialsService.kTypeLabels[material.type] ?? 'Material';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: scheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            material.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (material.subject.isNotEmpty)
                      Text(
                        material.subject +
                            (material.level.isNotEmpty
                                ? ' · ${material.level}'
                                : ''),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (material.fileName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        material.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (material.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        material.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.open_in_new, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}