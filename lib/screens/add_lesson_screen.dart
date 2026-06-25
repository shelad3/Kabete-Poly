import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/lesson.dart';
import '../models/template.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/class_provider.dart';
import '../services/auth_provider.dart';

class AddLessonScreen extends StatefulWidget {
  final Lesson? lessonToEdit;

  const AddLessonScreen({super.key, this.lessonToEdit});

  @override
  State<AddLessonScreen> createState() => _AddLessonScreenState();
}

class _AddLessonScreenState extends State<AddLessonScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();

  late TextEditingController _topicCtrl;
  late TextEditingController _subtopicCtrl;
  late TextEditingController _teacherCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _summaryCtrl;
  late TextEditingController _reportCtrl;
  late TextEditingController _nb1Ctrl;
  late TextEditingController _nb2Ctrl;

  final List<_AttachmentItem> _attachments = [];
  final StorageService _storageService = StorageService();

  bool _isLoading = false;

  Future<void> _pickDocuments() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        for (final file in result.files) {
          if (file.path != null) {
            _attachments.add(_AttachmentItem(
              file: File(file.path!),
              name: file.name,
            ));
          }
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _topicCtrl = TextEditingController(text: widget.lessonToEdit?.topic);
    _subtopicCtrl = TextEditingController(text: widget.lessonToEdit?.subtopic);
    _teacherCtrl = TextEditingController(text: widget.lessonToEdit?.teacher);
    _contentCtrl = TextEditingController(text: widget.lessonToEdit?.content);
    _summaryCtrl = TextEditingController(text: widget.lessonToEdit?.summary);
    _reportCtrl = TextEditingController(text: widget.lessonToEdit?.report);
    _nb1Ctrl = TextEditingController(text: widget.lessonToEdit?.nb1);
    _nb2Ctrl = TextEditingController(text: widget.lessonToEdit?.nb2);
    if (widget.lessonToEdit != null) {
      for (var i = 0; i < widget.lessonToEdit!.attachmentUrls.length; i++) {
        _attachments.add(_AttachmentItem(
          existingUrl: widget.lessonToEdit!.attachmentUrls[i],
          name: i < widget.lessonToEdit!.attachmentNames.length
              ? widget.lessonToEdit!.attachmentNames[i]
              : 'Attachment ${i + 1}',
        ));
      }
    }
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    _subtopicCtrl.dispose();
    _teacherCtrl.dispose();
    _contentCtrl.dispose();
    _summaryCtrl.dispose();
    _reportCtrl.dispose();
    _nb1Ctrl.dispose();
    _nb2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lessonToEdit == null ? 'Post New Lesson' : 'Edit Lesson'),
        actions: [
          if (widget.lessonToEdit == null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'save_template') {
                  _saveTemplate();
                } else if (v == 'load_template') _showTemplatePicker();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'save_template', child: ListTile(
                  leading: Icon(Icons.save_as, color: Colors.teal),
                  title: Text('Save as Template'),
                  dense: true,
                )),
                const PopupMenuItem(value: 'load_template', child: ListTile(
                  leading: Icon(Icons.file_copy, color: Colors.blue),
                  title: Text('Load Template'),
                  dense: true,
                )),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.class_, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Posting to: ${widget.lessonToEdit?.classId ?? context.read<ClassProvider>().currentClass}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildField(_topicCtrl, 'Topic', Icons.title),
              _buildField(_subtopicCtrl, 'Subtopic', Icons.subject),
              _buildField(_teacherCtrl, 'Teacher Name', Icons.person),
              _buildField(_contentCtrl, 'Main Notes Content', Icons.description, maxLines: 5),
              _buildField(_summaryCtrl, 'Summary of Notes', Icons.summarize, maxLines: 3),
              _buildField(_reportCtrl, 'Practical Report', Icons.assignment, maxLines: 3),
              Row(
                children: [
                  Expanded(child: _buildField(_nb1Ctrl, 'NB Column 1', Icons.note)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildField(_nb2Ctrl, 'NB Column 2', Icons.note)),
                ],
              ),
              const SizedBox(height: 16),
              _buildAttachmentSection(),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(widget.lessonToEdit == null ? 'Post Lesson' : 'Save Changes'),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveTemplate() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as Template'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Template Name',
            hintText: 'e.g. Weekly Report Format',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    try {
      final user = context.read<AuthProvider>().currentUser;
      final template = LessonTemplate(
        id: '',
        createdBy: user?.email ?? 'unknown',
        name: name,
        topic: _topicCtrl.text,
        subtopic: _subtopicCtrl.text,
        teacher: _teacherCtrl.text,
        content: _contentCtrl.text,
        summary: _summaryCtrl.text,
        report: _reportCtrl.text,
        nb1: _nb1Ctrl.text,
        nb2: _nb2Ctrl.text,
      );
      await _firestoreService.saveLessonTemplate(template);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template saved!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showTemplatePicker() {
    final user = context.read<AuthProvider>().currentUser;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return StreamBuilder<List<LessonTemplate>>(
          stream: _firestoreService.getLessonTemplatesStream(user?.email ?? ''),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ));
            }
            final templates = snap.data ?? [];
            if (templates.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No saved templates')),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Load Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: templates.length,
                    itemBuilder: (_, i) {
                      final t = templates[i];
                      return ListTile(
                        leading: const Icon(Icons.description, color: Colors.blue),
                        title: Text(t.name),
                        subtitle: Text('${t.topic} — ${t.subtopic}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => _firestoreService.deleteLessonTemplate(t.id),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _topicCtrl.text = t.topic;
                          _subtopicCtrl.text = t.subtopic;
                          _teacherCtrl.text = t.teacher;
                          _contentCtrl.text = t.content;
                          _summaryCtrl.text = t.summary;
                          _reportCtrl.text = t.report;
                          _nb1Ctrl.text = t.nb1;
                          _nb2Ctrl.text = t.nb2;
                          setState(() {});
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAttachmentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Attachments', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${_attachments.length} file(s)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._attachments.asMap().entries.map((entry) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.insert_drive_file, color: Colors.blue, size: 20),
                    title: Text(entry.value.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 18),
                      onPressed: () => setState(() => _attachments.removeAt(entry.key)),
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickDocuments,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Files'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final List<String> urls = [];
        final List<String> names = [];

        for (final att in _attachments) {
          if (att.file != null) {
            final path = 'lessons/docs/${DateTime.now().millisecondsSinceEpoch}_${att.name}';
            final url = await _storageService.uploadFile(att.file!, path);
            urls.add(url ?? '');
            names.add(att.name);
          } else if (att.existingUrl != null) {
            urls.add(att.existingUrl!);
            names.add(att.name);
          }
        }

        final classProvider = Provider.of<ClassProvider>(context, listen: false);
        final classId = widget.lessonToEdit?.classId ?? classProvider.currentClass;

        final lesson = Lesson(
          id: widget.lessonToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          classId: classId,
          topic: _topicCtrl.text,
          subtopic: _subtopicCtrl.text,
          teacher: _teacherCtrl.text,
          imageUrl: widget.lessonToEdit?.imageUrl,
          content: _contentCtrl.text,
          summary: _summaryCtrl.text,
          practicalPictures: widget.lessonToEdit?.practicalPictures ?? [],
          report: _reportCtrl.text,
          nb1: _nb1Ctrl.text,
          nb2: _nb2Ctrl.text,
          date: widget.lessonToEdit?.date ?? DateTime.now(),
          attachmentUrls: urls,
          attachmentNames: names,
        );

        if (widget.lessonToEdit == null) {
          await _firestoreService.addLesson(lesson);
        } else {
          await _firestoreService.updateLesson(lesson);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.lessonToEdit == null ? 'Lesson posted successfully!' : 'Changes saved!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving lesson: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
}

class _AttachmentItem {
  final File? file;
  final String name;
  final String? existingUrl;

  _AttachmentItem({this.file, required this.name, this.existingUrl});
}
