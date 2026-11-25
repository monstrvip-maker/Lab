class PromptQualityReport {
  const PromptQualityReport({
    required this.score,
    required this.strengths,
    required this.missing,
  });
  final int score;
  final List<String> strengths;
  final List<String> missing;
}

/// Heuristic checklist for the user's raw task, not for the generated prompt.
/// It rewards a clear request even when the user has not written a full spec.
class PromptQualityAnalyzer {
  static PromptQualityReport analyze(String source) {
    final text = source.trim();
    final lower = text.toLowerCase();
    if (text.isEmpty) {
      return const PromptQualityReport(
        score: 0,
        strengths: [],
        missing: ['Опиши, что нужно сделать и какой результат ожидаешь'],
      );
    }

    final strengths = <String>[];
    final missing = <String>[];
    var score = 0;
    void check(bool ok, int points, String good, String advice) {
      if (ok) {
        score += points;
        strengths.add(good);
      } else {
        missing.add(advice);
      }
    }

    final hasAction = RegExp(
      r'созда|разработ|сдела|спланир|напиш|реализ|постро|улучш|проанализ|состав|помог|обуч|управл|найти|создан',
    ).hasMatch(lower);
    final hasSubject = RegExp(
      r'прилож|систем|сайт|сервис|программ|проект|реб[её]н|моторик|игр|модел|устройств|лен|контроллер|бот|документ|текст|данн|процесс',
    ).hasMatch(lower);
    final hasAudience = RegExp(
      r'пользоват|клиент|реб[её]н|родител|педагог|сотрудник|для кого|аудитори',
    ).hasMatch(lower);
    final hasGoal = RegExp(
      r'цель|чтобы|для того|помога|обуч|управл|автоматиз|обеспеч|позвол|ожидаем',
    ).hasMatch(lower);
    final hasOutput = RegExp(
      r'формат|структур|план|этап|код|таблиц|список|прототип|приложени|техническ|тз|документ|результат',
    ).hasMatch(lower);
    final hasConstraints = RegExp(
      r'огранич|бюджет|срок|платформ|android|ios|windows|интернет|офлайн|без |нельзя|не использ|доступ|ресурс',
    ).hasMatch(lower);
    final hasAcceptance = RegExp(
      r'критер|провер|тест|готов|при[её]мк|должно работать|ошибк',
    ).hasMatch(lower);
    final hasContext = text.length >= 100 || text.split(RegExp(r'\\s+')).length >= 14;
    final hasConcreteDetail = RegExp(
      r'\\d|\\b(api|ai|gguf|flutter|python|sqlite|qwen|esp32|ws2812)\\b',
    ).hasMatch(lower);

    check(hasAction, 20, 'Понятно, какое действие требуется', 'Уточни, что именно нужно сделать');
    check(hasSubject, 15, 'Указан предмет задачи', 'Назови приложение, систему, проект или объект работы');
    check(hasGoal || (hasAction && hasSubject), 15, 'Понятно общее назначение задачи', 'Добавь, какую проблему нужно решить или какую цель достичь');
    check(hasOutput, 10, 'Обозначен ожидаемый тип результата', 'Укажи, что нужно получить: план, приложение, код, анализ или документ');
    check(hasAudience, 10, 'Указаны пользователи или аудитория', 'Уточни, кто будет пользоваться результатом');
    check(hasConstraints, 10, 'Есть ограничения или условия', 'Добавь платформу, бюджет, сроки или условия работы');
    check(hasAcceptance, 10, 'Есть критерии проверки', 'Добавь признаки, по которым можно понять, что задача выполнена');
    check(hasContext, 5, 'Достаточно исходного контекста', 'Добавь немного контекста и подробностей');
    check(hasConcreteDetail, 5, 'Есть конкретные технические детали', 'Если известны, добавь числа, технологии или параметры');

    return PromptQualityReport(
      score: score.clamp(0, 100).toInt(),
      strengths: strengths,
      missing: missing,
    );
  }
}
