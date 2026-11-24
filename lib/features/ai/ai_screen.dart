import 'package:flutter/material.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

import '../../ai/runtime/local_ai_runtime.dart';
import '../prompts/prompt_library_screen.dart';
import 'model_manager_screen.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _runtime = LocalAiRuntime.instance;
  final _input = TextEditingController();
  final List<ChatMessage> _history = [];
  final List<_ChatLine> _lines = [];
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _runtime.initialize();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _openModels() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ModelManagerScreen()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _generating) return;

    if (!_runtime.isLoaded) {
      await _openModels();
      if (!_runtime.isLoaded || !mounted) return;
    }

    _input.clear();
    _history.add(ChatMessage(role: 'user', content: text));
    setState(() {
      _lines.add(_ChatLine(text: text, isUser: true));
      _lines.add(_ChatLine(text: '', isUser: false));
      _generating = true;
    });

    final response = StringBuffer();
    try {
      await for (final token in _runtime.generateChat(
        messages: List<ChatMessage>.from(_history),
      )) {
        response.write(token);
        if (!mounted) return;
        setState(() => _lines.last.text = response.toString());
      }
      _history.add(ChatMessage(role: 'assistant', content: response.toString()));
    } catch (error) {
      if (mounted) {
        setState(() => _lines.last.text = 'Ошибка генерации: $error');
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _stop() async {
    await _runtime.stop();
    if (mounted) setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _runtime,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('AI Studio'),
          actions: [
            IconButton(
              tooltip: 'Менеджер моделей',
              onPressed: _openModels,
              icon: const Icon(Icons.memory),
            ),
            IconButton(
              tooltip: 'Библиотека промтов',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PromptLibraryScreen()),
              ),
              icon: const Icon(Icons.library_books_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    _runtime.isLoaded ? Icons.check_circle : Icons.circle_outlined,
                    color: _runtime.isLoaded
                        ? Colors.greenAccent
                        : Theme.of(context).colorScheme.outline,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _runtime.isLoaded
                          ? 'Локально · ${_runtime.modelName}'
                          : 'Локальная модель не загружена',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(onPressed: _openModels, child: const Text('Модели')),
                ],
              ),
            ),
            Expanded(
              child: _lines.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, size: 48),
                            const SizedBox(height: 14),
                            const Text(
                              'Локальный AI-чат',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Подключите модель Qwen в формате GGUF. После загрузки ответы будут генерироваться на телефоне.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _openModels,
                              icon: const Icon(Icons.add),
                              label: const Text('Добавить модель'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _lines.length,
                      itemBuilder: (context, index) {
                        final line = _lines[index];
                        return Align(
                          alignment: line.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.86,
                            ),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: line.isUser
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: SelectableText(
                              line.text.isEmpty && _generating ? '…' : line.text,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Напишите сообщение…',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _generating ? _stop : _send,
                      icon: Icon(_generating ? Icons.stop : Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatLine {
  _ChatLine({required this.text, required this.isUser});

  String text;
  final bool isUser;
}
