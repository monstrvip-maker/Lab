import 'package:flutter/material.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

import '../../ai/runtime/local_ai_runtime.dart';
import '../../data/models/prompt_record.dart';
import '../../data/repositories/advanced_repository.dart';

class PromptTestScreen extends StatefulWidget {
  const PromptTestScreen({super.key, required this.prompt});
  final PromptRecord prompt;

  @override
  State<PromptTestScreen> createState() => _PromptTestScreenState();
}

class _PromptTestScreenState extends State<PromptTestScreen> {
  final _runtime = LocalAiRuntime.instance;
  final _advanced = AdvancedRepository();
  final _input = TextEditingController();
  final _expected = TextEditingController();
  String _actual = '';
  String _evaluation = '';
  bool _running = false;

  @override
  void dispose() {
    _input.dispose();
    _expected.dispose();
    super.dispose();
  }

  Future<String> _complete(String prompt, {int tokens = 420}) async {
    final result = StringBuffer();
    await for (final token in _runtime.generateChat(
      messages: [ChatMessage(role: 'user', content: prompt)],
      maxTokens: tokens,
      temperature: 0.2,
    )) {
      result.write(token);
      if (!mounted) break;
    }
    return result.toString().trim();
  }

  Future<void> _runTest() async {
    if (_running || _input.text.trim().isEmpty) return;
    if (!_runtime.isLoaded) {
      setState(() => _evaluation = 'Сначала загрузите локальную модель Qwen в AI Studio.');
      return;
    }
    setState(() { _running = true; _actual = ''; _evaluation = 'Qwen выполняет тест…'; });
    try {
      final template = widget.prompt.improvedText?.trim().isNotEmpty == true
          ? widget.prompt.improvedText!.trim() : widget.prompt.originalText;
      final actual = await _complete('''
Выполни следующий промт строго по его инструкции.
ПРОМТ:
$template

ТЕСТОВЫЕ ВХОДНЫЕ ДАННЫЕ:
${_input.text.trim()}
''');
      if (!mounted) return;
      setState(() => _actual = actual);
      final expected = _expected.text.trim();
      var passed = false;
      var notes = '';
      if (expected.isEmpty) {
        notes = 'Ожидаемый результат не задан; результат сохранён как непроверенный.';
        passed = false;
      } else {
        final verdict = await _complete('''
Ты — строгий оценщик теста промта. Сравни ожидаемый результат с фактическим.
Ожидается:
$expected
Получено:
$actual
Верни первую строку строго PASS или FAIL, затем короткое объяснение. PASS только если выполнены все существенные требования.
''', tokens: 100);
        passed = verdict.toUpperCase().startsWith('PASS');
        notes = verdict;
      }
      await _advanced.savePromptTest(
        promptId: widget.prompt.id,
        input: _input.text.trim(),
        expected: expected,
        actual: actual,
        passed: passed,
        notes: notes,
      );
      if (mounted) setState(() => _evaluation = expected.isEmpty
          ? notes : '${passed ? 'PASS' : 'FAIL'} · $notes');
    } catch (error) {
      if (mounted) setState(() => _evaluation = 'Ошибка теста: $error');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Тестирование промта')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text(widget.prompt.title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      TextField(controller: _input, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Тестовые входные данные')),
      const SizedBox(height: 10),
      TextField(controller: _expected, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Ожидаемый результат или критерии', hintText: 'Нужен для автоматической оценки PASS/FAIL')),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _running ? null : _runTest, icon: const Icon(Icons.play_arrow), label: Text(_running ? 'Выполняется…' : 'Запустить на локальной Qwen')),
      if (_running) const LinearProgressIndicator(),
      if (_actual.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text('Фактический результат', style: Theme.of(context).textTheme.titleMedium),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: SelectableText(_actual))),
      ],
      if (_evaluation.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('Оценка и сохранение', style: Theme.of(context).textTheme.titleMedium),
        Text(_evaluation),
      ],
      const SizedBox(height: 10),
      Text('Тест выполняется локальной моделью. PASS/FAIL — оценка Qwen по заданным критериям, а не гарантия правильности.', style: Theme.of(context).textTheme.bodySmall),
    ]),
  );
}
