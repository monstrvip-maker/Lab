class PromptTemplateQualityReport {
  const PromptTemplateQualityReport({
    required this.score,
    required this.isUsable,
    required this.strengths,
    required this.issues,
  });

  final int score;
  final bool isUsable;
  final List<String> strengths;
  final List<String> issues;
}

/// Transparent structural checks for reusable prompt templates.
/// This is a heuristic gate, not an AI benchmark.
class PromptTemplateQualityAnalyzer {
  static PromptTemplateQualityReport analyze(String source) {
    final text = source.trim();
    final lower = text.toLowerCase();
    if (text.length < 150) {
      return const PromptTemplateQualityReport(
        score: 0,
        isUsable: false,
        strengths: [],
        issues: ['Шаблон слишком короткий: требуется не менее 150 символов.'],
      );
    }

    final hasRole = RegExp(
      r'роль|ты\s*[-—:]|выступай\s+как|you are|act as|role:',
      caseSensitive: false,
    ).hasMatch(lower);
    final hasGoal = RegExp(
      r'цель|задач[аеиу]|сделай|создай|проанализируй|подготовь|разработай|objective|task:',
      caseSensitive: false,
    ).hasMatch(lower);
    final hasInput = RegExp(
      r'входн[а-яё]*\s+данн|контекст|исходн[а-яё]*\s+данн|input:|context:',
      caseSensitive: false,
    ).hasMatch(lower);
    final hasPlaceholder = RegExp(r'\[[^\]]{2,}\]').hasMatch(text);
    final hasSteps = RegExp(
      r'шаг|этап|алгоритм|последовательност|сначала|затем|инструкц|step\s+\d|first,|then',
      caseSensitive: false,
    ).hasMatch(lower);
    final hasOutput = RegExp(
      r'формат\s+(ответ|результат)|результат:|выведи|представь\s+результат|output:|response:',
      caseSensitive: false,
    ).hasMatch(lower);
    final hasConstraints = RegExp(
      r'ограничен|не\s+выдум|если\s+неизвестно|проверяй|не\s+добавляй|constraints:',
      caseSensitive: false,
    ).hasMatch(lower);
    final hasCjk = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);

    final strengths = <String>[];
    final issues = <String>[];
    var score = 0;
    void award(bool ok, int points, String good, String issue) {
      if (ok) {
        score += points;
        strengths.add(good);
      } else {
        issues.add(issue);
      }
    }

    award(hasRole, 20, 'Определена роль исполнителя', 'Добавь роль: кем должен выступать AI.');
    award(hasGoal, 20, 'Сформулирована задача', 'Чётко сформулируй задачу и ожидаемую цель.');
    award(hasInput || hasPlaceholder, 15, 'Есть входные данные или плейсхолдеры', 'Добавь входные данные или плейсхолдеры [КОНТЕКСТ], [ТЕКСТ].');
    award(hasSteps, 15, 'Есть порядок выполнения', 'Опиши последовательность действий или этапы.');
    award(hasOutput, 15, 'Определён формат результата', 'Укажи структуру и формат итогового ответа.');
    award(hasConstraints, 10, 'Есть ограничения и проверка фактов', 'Добавь ограничения, запрет на выдумывание и правила работы с неизвестными данными.');
    award(text.length >= 350, 5, 'Достаточная детализация', 'Раскрой детали шаблона, чтобы его можно было повторно использовать.');

    if (hasCjk) {
      score = 0;
      issues.add('Обнаружены китайские иероглифы: проверь корректность извлечения текста.');
    }
    final structurallyComplete = hasRole && hasGoal &&
        (hasInput || hasPlaceholder) && (hasSteps || hasOutput) &&
        hasOutput && !hasCjk;
    return PromptTemplateQualityReport(
      score: score.clamp(0, 100).toInt(),
      isUsable: structurallyComplete && score >= 65,
      strengths: strengths,
      issues: issues,
    );
  }
}
