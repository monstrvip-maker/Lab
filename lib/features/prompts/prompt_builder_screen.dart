import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import '../../ai/runtime/local_ai_runtime.dart';
import '../../data/repositories/prompt_repository.dart';

class PromptBuilderScreen extends StatefulWidget {
  const PromptBuilderScreen({super.key, this.initialText = ''});
  final String initialText;
  @override
  State<PromptBuilderScreen> createState() => _PromptBuilderScreenState();
}

class _PromptBuilderScreenState extends State<PromptBuilderScreen> {
  final _runtime = LocalAiRuntime.instance;
  final _repository = PromptRepository();
  late final TextEditingController _input;
  String _result = '';
  bool _working = false;
  String? _error;

  @override
  void initState() { super.initState(); _input = TextEditingController(text: widget.initialText); _runtime.initialize(); }
  @override
  void dispose() { _input.dispose(); super.dispose(); }

  Future<void> _buildPrompt() async {
    if (_working || _input.text.trim().isEmpty) return;
    if (!_runtime.isLoaded) {
      setState(() => _error = 'Сначала загрузите локальную модель в AI Studio → Модели.');
      return;
    }
    setState(() { _working = true; _result = ''; _error = null; });
    final instruction = '''
Ты — инженер по проектированию промтов. Преобразуй запрос пользователя в готовый качественный промт на русском языке.
Сохрани исходную цель. Уточни роль модели, контекст, входные данные, ограничения, пошаговую задачу, формат результата и критерии качества.
Не выдумывай факты и не добавляй неоговорённые требования. Если данных не хватает, перечисли короткие уточнения в конце, но сначала дай максимально полезную версию с явно отмеченными допущениями.
Верни только готовый промт и при необходимости блок «Что уточнить».
Запрос пользователя:
${_input.text.trim()}
''';
    try {
      await for (final token in _runtime.generateChat(
        messages: [ChatMessage(role: 'user', content: instruction)],
        maxTokens: 700,
        temperature: 0.35,
      )) {
        if (!mounted) return;
        setState(() => _result += token);
      }
      if (_result.trim().isEmpty) _error = 'Модель не вернула текст. Попробуйте сократить запрос.';
    } catch (e) {
      _error = 'Ошибка генерации: $e';
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _save() async {
    if (_result.trim().isEmpty) return;
    await _repository.create(title: _input.text.trim().split('\n').first, originalText: _input.text.trim(), category: 'Создано AI',);
    await _repository.create(title: 'Улучшенный промт · ${_input.text.trim().split('\n').first}', originalText: _result.trim(), category: 'Улучшено AI');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Оригинал и улучшенная версия сохранены в библиотеке')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Конструктор промтов')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text('Исходная задача', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      TextField(controller: _input, minLines: 4, maxLines: 8, decoration: const InputDecoration(hintText: 'Опиши, что должна сделать AI-модель…')),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _working ? null : _buildPrompt, icon: const Icon(Icons.auto_awesome), label: Text(_working ? 'Создаю промт…' : 'Создать с помощью Qwen')),
      if (_working) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      if (_result.isNotEmpty) ...[
        const SizedBox(height: 22),
        Text('Готовый промт', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: SelectableText(_result))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: _result)), icon: const Icon(Icons.copy), label: const Text('Копировать')),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Сохранить обе версии')),
        ]),
      ],
      const SizedBox(height: 16),
      Text('Работает на выбранной локальной GGUF-модели. Внешние AI API не используются.', style: Theme.of(context).textTheme.bodySmall),
    ]),
  );
}
