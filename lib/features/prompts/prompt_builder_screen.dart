import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import '../../ai/runtime/local_ai_runtime.dart';
import '../../data/repositories/prompt_repository.dart';
import '../../ai/prompts/prompt_quality_analyzer.dart';

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
  bool _saved = false;
  String? _error;

  PromptQualityReport get _quality => PromptQualityAnalyzer.analyze(_input.text);

  bool get _isLedProject => RegExp(
    r'led.?лен|led.?strip|ws2812|esp32|адресн.*лент',
    caseSensitive: false,
  ).hasMatch(_input.text);

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.initialText);
    _runtime.initialize();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String _buildInstruction(String task) {
    final ledContext = _isLedProject
        ? '''
Проверенный контекст проекта, который нужно учитывать как исходные вводные:
- Контроллер: ESP32-S2 Mini (WEMOS LOLIN S2 Mini).
- Лента: WS2812B, 100 светодиодов.
- Линия данных: GPIO16.
- Приложение: Flutter, целевые платформы Android и Windows.
- Направление прошивки: ESPHome; приложение должно обнаруживать ESPHome-устройства напрямую, без обязательного Home Assistant.
- Для адресной ленты важно учитывать порядок цветов (в проекте нужен настраиваемый профиль RGB/GRB/BGR).
Не подменяй эти вводные другими платами, количеством светодиодов, GPIO или средами разработки. Если пользовательская задача явно задаёт другие значения, приоритет у неё; конфликт вынеси в «Требует уточнения».
'''
        : '';

    return '''
Ты — старший системный аналитик и инженер по проектированию программных решений. Твоя задача — превратить запрос в конкретное техническое задание-промт, по которому другая AI-модель сможет выполнить работу без догадок.

ИСХОДНЫЙ ЗАПРОС:
$task

$ledContext

ПРАВИЛА:
1. Не пересказывай запрос общими словами. Преврати его в конкретные проверяемые требования.
2. Не выдумывай аппаратные параметры, библиотеки, протоколы, версии, функции и результаты тестов.
3. Отделяй известные вводные от неизвестных. Неизвестное помечай как «не задано» и формулируй точный вопрос только если без ответа нельзя принять архитектурное решение.
4. Не навязывай Arduino IDE, Home Assistant, облачные API или другую платформу, если она не следует из исходных данных.
5. Если задача о разработке, обязательно включи архитектуру модулей и потоков данных, этапы реализации, критерии готовности, обработку ошибок и план проверок.
6. Для аппаратных проектов проверь совместимость контроллера, периферии, питания, интерфейсов и ограничений платформы. Не объявляй проверку выполненной — составь план проверок.
7. Каждый раздел выведи ровно один раз. Не печатай предварительное оглавление или список заголовков перед содержанием. Не повторяй исходные данные в нескольких разделах.\n8. Если исходных данных мало, не заполняй объём выдумками: коротко укажи неизвестное и оставь вопросы в последнем разделе.\n9. Сохраняй единый порядок разделов; не добавляй второй экземпляр раздела в конце.

ФОРМАТ ОТВЕТА:
# Роль исполнителя
# Цель и ожидаемый результат
# Подтверждённые исходные данные
# Функциональные требования
# Архитектура и взаимодействие компонентов
# Этапы реализации с результатами каждого этапа
# Проверки, тест-кейсы и критерии приёмки
# Риски и обработка ошибок
# Неизвестные данные и вопросы (только действительно необходимые)

Пиши по-русски, технически точно и достаточно подробно, но без повторов. Сначала сразу пиши содержимое первого раздела, без оглавления. Каждый раздел должен быть один раз. Верни только готовый промт. Не добавляй вымышленные ответы на вопросы.
''';
  }

  Future<void> _buildPrompt() async {
    final task = _input.text.trim();
    if (_working || task.isEmpty) return;
    if (!_runtime.isLoaded) {
      setState(() => _error = 'Сначала загрузите локальную модель в AI Studio → Модели.');
      return;
    }
    setState(() {
      _working = true;
      _result = '';
      _error = null;
      _saved = false;
    });
    try {
      await for (final token in _runtime.generateChat(
        messages: [ChatMessage(role: 'user', content: _buildInstruction(task))],
        maxTokens: 900,
        temperature: 0.2,
      )) {
        if (!mounted) return;
        setState(() => _result += token);
      }
      if (_result.trim().isEmpty) {
        _error = 'Модель не вернула текст. Попробуйте уточнить или сократить задачу.';
      }
    } catch (e) {
      _error = 'Ошибка генерации: $e';
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _save() async {
    if (_result.trim().isEmpty || _saved) return;
    try {
      await _repository.createWithImproved(
        title: _input.text.trim().split('\n').first,
        originalText: _input.text.trim(),
        improvedText: _result.trim(),
        category: _isLedProject ? 'Разработка · Умный дом' : 'Создано AI',
      );
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Промт и обе версии сохранены в одной записи библиотеки')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Не удалось сохранить промт: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Конструктор промтов')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text('Исходная задача', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _input,
          minLines: 4,
          maxLines: 8,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Опиши задачу, ограничения и ожидаемый результат…',
            alignLabelWithHint: true,
          ),
        ),
        if (_isLedProject) ...[
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.memory_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Распознан контекст LED-проекта: ESP32-S2 Mini, WS2812B · 100 LED, GPIO16, Flutter Android/Windows, ESPHome. Эти вводные будут переданы Qwen.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text('Качество исходного запроса', style: Theme.of(context).textTheme.titleSmall)), Text('${_quality.score}/100', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _quality.score / 100),
          const SizedBox(height: 8),
          if (_quality.missing.isEmpty) const Text('Хорошая структура. Можно создавать промт.') else ..._quality.missing.take(4).map((item) => Padding(padding: const EdgeInsets.only(top: 3), child: Text('• $item', style: Theme.of(context).textTheme.bodySmall))),
        ]))),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _working ? null : _buildPrompt,
          icon: const Icon(Icons.auto_awesome),
          label: Text(_working ? 'Создаю промт…' : 'Создать с помощью Qwen'),
        ),
        if (_working) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 6),
          Text('Qwen формирует техническое задание на телефоне…', style: Theme.of(context).textTheme.bodySmall),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (_result.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('Готовый промт', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SelectableText(_result),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _result));
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Готовый промт скопирован')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Копировать'),
              ),
              FilledButton.icon(
                onPressed: _saved ? null : _save,
                icon: Icon(_saved ? Icons.check : Icons.save_outlined),
                label: Text(_saved ? 'Сохранено' : 'Сохранить промт и версии'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Генерация выполняется выбранной локальной GGUF-моделью. Интернет и внешние AI API не используются.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
