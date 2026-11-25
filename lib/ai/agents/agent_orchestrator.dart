import 'package:llama_flutter_android/llama_flutter_android.dart';

import '../runtime/local_ai_runtime.dart';

/// Runs specialist roles sequentially on one loaded local model.
/// Each stage receives compact context to stay within mobile context limits.
class AgentOrchestrator {
  AgentOrchestrator(this.runtime);

  final LocalAiRuntime runtime;

  static const _roles = <({String name, String instruction})>[
    (name: 'ПЛАНИРОВЩИК', instruction: 'Кратко определи цель, ограничения и 3–5 последовательных этапов. Не описывай несуществующие действия.'),
    (name: 'АРХИТЕКТОР', instruction: 'Предложи конкретные компоненты, их ответственность и связи. Укажи технические риски. Не повторяй план целиком.'),
    (name: 'ЭКСПЕРТ', instruction: 'Дай практические технические рекомендации. Отделяй факты от предположений. Не повторяй предыдущие ответы.'),
    (name: 'КРИТИК', instruction: 'Найди ошибки и пробелы в предыдущих выводах. Исправь их и выдай согласованный итог с приоритетными шагами.'),
  ];

  String _compact(String value, {int limit = 700}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= limit) return normalized;
    return '${normalized.substring(0, limit)}…';
  }

  Stream<String> run(String task) async* {
    final originalTask = _compact(task, limit: 900);
    final summaries = <String>[];

    for (final role in _roles) {
      yield '\n\n${role.name}\n';
      final previous = summaries.isEmpty
          ? 'Предыдущих результатов пока нет.'
          : summaries.join('\n');
      final prompt = '''
Ты — ${role.name}, один из четырёх последовательных специалистов.
${role.instruction}

Задача пользователя:
$originalTask

Краткие результаты предыдущих ролей:
$previous

Ответь по-русски простым текстом. Не используй Markdown-заголовки и длинные вступления.
Ограничь ответ примерно 100 словами. Не утверждай, что выполнял действия или проверял код, если этого не было.
'''

      final result = StringBuffer();
      try {
        await for (final token in runtime.generateChat(
          messages: [ChatMessage(role: 'user', content: prompt)],
          maxTokens: 128,
          temperature: 0.3,
        )) {
          result.write(token);
          yield token;
        }
      } catch (error) {
        yield '\nНе удалось выполнить этап ${role.name}: $error';
        return;
      }

      final output = result.toString().trim();
      if (output.isEmpty) {
        yield '\nЭтап ${role.name} не вернул текст. Последующие этапы остановлены.';
        return;
      }
      summaries.add('${role.name}: ${_compact(output)}');
    }
  }
}