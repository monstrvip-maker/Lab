import 'package:llama_flutter_android/llama_flutter_android.dart';

import '../runtime/local_ai_runtime.dart';

/// Runs specialist roles one after another on the same local model.
/// This is orchestration by prompting, not separate concurrently running models.
class AgentOrchestrator {
  AgentOrchestrator(this.runtime);

  final LocalAiRuntime runtime;

  static const _roles = <({String name, String instruction})>[
    (
      name: 'ПЛАНИРОВЩИК',
      instruction: 'Разбей запрос на понятные шаги. Укажи цель, ограничения и порядок выполнения. Не выдумывай выполненные действия.',
    ),
    (
      name: 'АРХИТЕКТОР',
      instruction: 'Предложи структуру решения, компоненты и связи между ними. Отметь риски и недостающие данные.',
    ),
    (
      name: 'ЭКСПЕРТ',
      instruction: 'Подготовь практическое решение по задаче. Будь точным, не заявляй о возможностях, которых нет.',
    ),
    (
      name: 'КРИТИК',
      instruction: 'Проверь предыдущие этапы на ошибки, противоречия и неподтверждённые обещания. Затем дай улучшенный итоговый ответ.',
    ),
  ];

  Stream<String> run(String task) async* {
    var workingContext = 'Задача пользователя:\n$task';

    for (final role in _roles) {
      yield '\n\n### ${role.name}\n';
      final prompt = '''
Ты — роль ${role.name} в последовательной системе локальных AI-агентов.
${role.instruction}

Контекст задачи и предыдущих этапов:
$workingContext

Отвечай по-русски. Если данных недостаточно, явно укажи это.
''';
      final result = StringBuffer();
      await for (final token in runtime.generateChat(
        messages: [ChatMessage(role: 'user', content: prompt)],
        maxTokens: 220,
        temperature: 0.4,
      )) {
        result.write(token);
        yield token;
      }
      workingContext += '\n\nРезультат этапа ${role.name}:\n${result.toString()}';
    }
  }
}
