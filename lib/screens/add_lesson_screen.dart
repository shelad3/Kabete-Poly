import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/lesson.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/class_provider.dart';

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
  
  File? _attachedFile;
  String? _attachmentName;
  final StorageService _storageService = StorageService();
  
  bool _isLoading = false;

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _attachedFile = File(result.files.single.path!);
        _attachmentName = result.files.single.name;
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
    _attachmentName = widget.lessonToEdit?.attachmentName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lessonToEdit == null ? 'Post New Lesson' : 'Edit Lesson'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
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
              // Document Attachment UI
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _attachmentName ?? 'Attach Document (PDF, DOCX, PPTX)',
                        style: TextStyle(
                          color: _attachmentName != null ? Colors.black87 : Colors.blueGrey,
                          fontWeight: _attachmentName != null ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_attachmentName != null)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _attachedFile = null;
                            _attachmentName = null;
                          });
                        },
                      )
                    else
                      ElevatedButton(
                        onPressed: _pickDocument,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          elevation: 0,
                          side: const BorderSide(color: Colors.blue),
                        ),
                        child: const Text('Browse'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(widget.lessonToEdit == null ? 'Post Lesson' : 'Save Changes'),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
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
        String? docUrl = widget.lessonToEdit?.attachmentUrl;
        String? docName = widget.lessonToEdit?.attachmentName;

        if (_attachedFile != null) {
          final path = 'lessons/docs/${DateTime.now().millisecondsSinceEpoch}_$_attachmentName';
          docUrl = await _storageService.uploadFile(_attachedFile!, path);
          docName = _attachmentName;
        }

        // If the user cleared the attachment entirely
        if (_attachedFile == null && _attachmentName == null) {
          docUrl = null;
          docName = null;
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
          attachmentUrl: docUrl,
          attachmentName: docName,
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
