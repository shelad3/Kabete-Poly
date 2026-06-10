import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/class_provider.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../models/schedule_item.dart';
import '../models/class_notification.dart';

class ScheduleUpcomingScreen extends StatefulWidget {
  final bool isPractical;

  const ScheduleUpcomingScreen({super.key, required this.isPractical});

  @override
  State<ScheduleUpcomingScreen> createState() => _ScheduleUpcomingScreenState();
}

class _ScheduleUpcomingScreenState extends State<ScheduleUpcomingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _roomController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<_AttachmentItem> _attachments = [];

  bool _isSaving = false;
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _saveAndSync() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields, including date and times.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final classId = Provider.of<ClassProvider>(context, listen: false).currentClass;
      final startTimeStr = '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';
      final endTimeStr = '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}';

      final List<String> urls = [];
      final List<String> names = [];
      for (final att in _attachments) {
        final path = 'attachments/$classId/${DateTime.now().millisecondsSinceEpoch}_${att.name}';
        final url = await _storageService.uploadFile(att.file, path);
        urls.add(url ?? '');
        names.add(att.name);
      }

      final scheduleItem = ScheduleItem(
        id: '',
        classId: classId,
        subject: _topicController.text.trim(),
        teacher: 'me',
        room: _roomController.text.trim(),
        startTime: startTimeStr,
        endTime: endTimeStr,
        color: widget.isPractical ? Colors.purple : Colors.orange,
        date: _selectedDate!,
        description: widget.isPractical ? 'Practical Lab Session' : 'Theory Class',
        attachmentUrls: urls,
        attachmentNames: names,
      );

      await _firestoreService.addScheduleItem(scheduleItem);

      final notification = ClassNotification(
        id: '',
        classId: classId,
        title: 'New ${widget.isPractical ? 'Practical' : 'Class'} Scheduled',
        message: '${_topicController.text.trim()} is scheduled for ${_selectedDate!.month}/${_selectedDate!.day} at $startTimeStr in ${_roomController.text.trim()}.',
        type: widget.isPractical ? 'event' : 'general',
        timestamp: DateTime.now(),
      );

      await _firestoreService.sendNotification(notification);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Omni-Sync successful. Class scheduled & notification sent.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isPractical ? 'Schedule Practical' : 'Schedule Theory'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Consumer<ClassProvider>(
                builder: (context, provider, _) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 12),
                      const Text('Posting to:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text(provider.currentClass, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('1. Topic & Details', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _topicController,
                decoration: const InputDecoration(labelText: 'Topic/Subject Name', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _roomController,
                decoration: InputDecoration(labelText: widget.isPractical ? 'Lab Room' : 'Classroom', border: const OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              const Text('2. Class Type', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Card(
                color: widget.isPractical ? Colors.purple.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                child: ListTile(
                  leading: Icon(widget.isPractical ? Icons.science : Icons.book,
                    color: widget.isPractical ? Colors.purple : Colors.orange),
                  title: Text(widget.isPractical ? 'Practical Lab Session' : 'Normal Theory Class',
                    style: TextStyle(fontWeight: FontWeight.bold,
                    color: widget.isPractical ? Colors.purple : Colors.orange)),
                ),
              ),
              const SizedBox(height: 24),

              const Text('3. Attachments (Optional)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    if (_attachments.isNotEmpty)
                      ..._attachments.asMap().entries.map((entry) => Card(
                        margin: const EdgeInsets.only(bottom: 4),
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
                    OutlinedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(_attachments.isEmpty ? 'Attach Notes / Practical PDF' : 'Add More Files'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('4. Schedule Timeline', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_selectedDate == null ? 'Select Date' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectTime(context, true),
                      icon: const Icon(Icons.access_time),
                      label: Text(_startTime == null ? 'Start Time' : _startTime!.format(context)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectTime(context, false),
                      icon: const Icon(Icons.access_time),
                      label: Text(_endTime == null ? 'End Time' : _endTime!.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveAndSync,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isSaving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Omni-Sync & Publish', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentItem {
  final File file;
  final String name;

  _AttachmentItem({required this.file, required this.name});
}
