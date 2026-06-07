import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/quiz.dart';
import '../../models/question.dart';
import '../../services/quiz_service.dart';
import '../../services/auth_provider.dart';

class TakeQuizScreen extends StatefulWidget {
  final Quiz quiz;
  const TakeQuizScreen({super.key, required this.quiz});

  @override
  State<TakeQuizScreen> createState() => _TakeQuizScreenState();
}

class _TakeQuizScreenState extends State<TakeQuizScreen> {
  final QuizService _service = QuizService();
  List<Question>? _questions;
  final Map<int, int> _answers = {};
  int _currentPage = 0;
  late PageController _pageCtrl;
  int _remainingSeconds = 0;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final questions = await _service.getQuestions(widget.quiz.id);
    if (mounted) {
      setState(() {
        _questions = questions;
        _remainingSeconds = widget.quiz.durationMinutes * 60;
      });
      _startTimer();
    }
  }

  void _startTimer() {
      Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || _submitted) return false;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
        return true;
      } else {
        _submitQuiz(autoSubmit: true);
        return false;
      }
    });
  }

  Future<void> _submitQuiz({bool autoSubmit = false}) async {
    if (_submitted) return;
    setState(() => _submitted = true);

    final questions = _questions ?? [];
    int score = 0;
    for (int i = 0; i < questions.length; i++) {
      if (_answers[i] == questions[i].correctIndex) {
        score += questions[i].points;
      }
    }

    final total = questions.fold<int>(0, (sum, q) => sum + q.points);
    final user = context.read<AuthProvider>().currentUser;

    await _service.submitQuiz(
      QuizSubmission(
        id: '',
        quizId: widget.quiz.id,
        userId: context.read<AuthProvider>().currentUserId,
        studentName: user?.fullName ?? 'Unknown',
        answers: _answers.map((k, v) => MapEntry(k.toString(), v.toString())),
        score: score,
        total: total,
        submittedAt: DateTime.now(),
      ),
    );

    if (mounted) {
      _showResult(score, total, autoSubmit);
    }
  }

  void _showResult(int score, int total, bool timedOut) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(timedOut ? 'Time\'s Up!' : 'Quiz Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your Score', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('$score / $total', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${((score / total) * 100).round()}%',
                style: TextStyle(fontSize: 18, color: score / total >= 0.5 ? Colors.green : Colors.red)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitted,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_submitted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Leave Quiz?'),
              content: const Text('Your progress will be lost.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Stay')),
                ElevatedButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text('Leave')),
              ],
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz.title),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: _questions != null
                ? LinearProgressIndicator(
                    value: _answers.length / (_questions!.length),
                    backgroundColor: Colors.grey[300],
                  )
                : const SizedBox.shrink(),
          ),
        ),
        body: _questions == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: _remainingSeconds < 60 ? Colors.red.withValues(alpha: 0.1) : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_answers.length}/${_questions!.length} answered',
                            style: TextStyle(color: Colors.grey[600])),
                        Row(
                          children: [
                            Icon(Icons.timer, size: 16, color: _remainingSeconds < 60 ? Colors.red : Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _remainingSeconds < 60 ? Colors.red : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageCtrl,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      itemCount: _questions!.length,
                      itemBuilder: (context, index) {
                        final q = _questions![index];
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Question ${index + 1} of ${_questions!.length}',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                              const SizedBox(height: 12),
                              Text(q.text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 24),
                              ...q.options.asMap().entries.map((entry) {
                                final oi = entry.key;
                                final option = entry.value;
                                final selected = _answers[index] == oi;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
                                    onTap: () => setState(() => _answers[index] = oi),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: selected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: selected ? Theme.of(context).primaryColor : Colors.grey[300]!,
                                          width: selected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                            color: selected ? Theme.of(context).primaryColor : Colors.grey,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(child: Text(option, style: const TextStyle(fontSize: 16))),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentPage > 0)
                          OutlinedButton(
                            onPressed: () => _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                            child: const Text('Previous'),
                          )
                        else
                          const SizedBox.shrink(),
                        if (_currentPage < (_questions?.length ?? 1) - 1)
                          ElevatedButton(
                            onPressed: () => _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                            child: const Text('Next'),
                          )
                        else
                          ElevatedButton(
                            onPressed: _submitted ? null : () => _submitQuiz(),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            child: const Text('Submit'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
