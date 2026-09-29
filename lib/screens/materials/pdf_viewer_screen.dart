import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  PdfController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response =
          await http.get(Uri.parse(widget.url)).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final document =
          await PdfDocument.openData(response.bodyBytes, password: '');
      if (!mounted) {
        await document.close();
        return;
      }
      setState(() {
        _controller = PdfController(document: Future.value(document));
      });
    } catch (e, _) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    setState(() => _error = null);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      backgroundColor: const Color(0xFF37474F),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Could not load this PDF. Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _retry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return PdfView(controller: controller);
  }
}