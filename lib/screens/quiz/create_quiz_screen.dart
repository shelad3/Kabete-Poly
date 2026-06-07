import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/quiz.dart';
import '../../models/question.dart';
import '../../services/quiz_service.dart';
import '../../services/auth_provider.dart';
import '../../services/class_provider.dart';

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '10');
  final _formKey = GlobalKey<FormState>();
  final QuizService _service = QuizService();
  final List<_QuestionForm> _questions = [];
  bool _isSaving = false;

  void _addQuestion() {
    setState(() => _questions.add(_QuestionForm()));
  }

  void _removeQuestion(int index) {
    setState(() => _questions.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final validQuestions = _questions.where((q) => q.isValid).toList();
    if (validQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one question'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    final user = context.read<AuthProvider>().currentUser;
    final classProvider = context.read<ClassProvider>();

    final quiz = Quiz(
      id: '',
      classId: classProvider.currentClass,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      durationMinutes: int.tryParse(_durationCtrl.text) ?? 10,
      createdBy: user?.fullName ?? 'Unknown',
      createdAt: DateTime.now(),
      isPublished: false,
    );

    final quizId = await _service.createQuiz(quiz);
    final questionIds = <String>[];

    for (final qf in validQuestions) {
      final q = Question(
        id: '',
        quizId: quizId,
        text: qf.controller.text.trim(),
        options: qf.options.map((o) => o.text.trim()).toList(),
        correctIndex: qf.correctIndex,
        points: 1,
      );
      final qId = await _service.addQuestion(q);
      questionIds.add(qId);
    }

    await _service.updateQuiz(quizId, {'questionIds': questionIds});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz created!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    for (final q in _questions) {
      q.controller.dispose();
      for (final o in q.options) {
        o.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Quiz'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Quiz Title', hintText: 'e.g. Chapter 5 Quiz'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description (optional)', hintText: 'Brief description'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _durationCtrl,
              decoration: const InputDecoration(labelText: 'Duration (minutes)'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = int.tryParse(v);
                if (n == null || n < 1) return 'Must be a positive number';
                return null;
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Questions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            ..._questions.asMap().entries.map((entry) {
              final i = entry.key;
              final qf = entry.value;
              return _buildQuestionCard(i, qf);
            }),
            if (_questions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('Tap "Add" to create questions', style: TextStyle(color: Colors.grey[500])),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, _QuestionForm qf) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  child: Text('${index + 1}', style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Text('Question ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                  onPressed: () => _removeQuestion(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: qf.controller,
              decoration: const InputDecoration(
                hintText: 'Enter question text',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ...qf.options.asMap().entries.map((entry) {
              final oi = entry.key;
              final oc = entry.value;
              final isCorrect = qf.correctIndex == oi;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Radio<int>(
                      value: oi,
                      groupValue: qf.correctIndex,
                      onChanged: (v) => setState(() => qf.correctIndex = v!),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: oc,
                        decoration: InputDecoration(
                          hintText: 'Option ${oi + 1}',
                          border: const OutlineInputBorder(),
                          suffixIcon: isCorrect ? const Icon(Icons.check_circle, color: Colors.green, size: 20) : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _QuestionForm {
  final TextEditingController controller = TextEditingController();
  final List<TextEditingController> options = List.generate(4, (_) => TextEditingController());
  int correctIndex = 0;

  bool get isValid => controller.text.trim().isNotEmpty && options.every((o) => o.text.trim().isNotEmpty);
}
