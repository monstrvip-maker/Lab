class PromptQualityReport {
  const PromptQualityReport({required this.score, required this.strengths, required this.missing});
  final int score;
  final List<String> strengths;
  final List<String> missing;
}

class PromptQualityAnalyzer {
  static PromptQualityReport analyze(String source) {
    final text = source.trim();
    final lower = text.toLowerCase();
    final strengths = <String>[];
    final missing = <String>[];
    var score = 0;
    void check(bool ok, int points, String good, String bad) {
      if (ok) { score += points; strengths.add(good); } else { missing.add(bad); }
    }
    check(text.length >= 80, 10, 'Есть достаточно исходного контекста', 'Добавь контекст и подробности задачи');
    check(RegExp(r'цель|задач|результат|нужно|требуется').hasMatch(lower), 15, 'Обозначена цель', 'Явно сформулируй цель и ожидаемый результат');
    check(RegExp(r'формат|структур|таблиц|список|json|markdown').hasMatch(lower), 10, 'Задан формат результата', 'Укажи желаемый формат ответа');
    check(RegExp(r'огранич|нельзя|не использ|бюджет|срок|платформ').hasMatch(lower), 15, 'Указаны ограничения', 'Добавь ограничения и условия выполнения');
    check(RegExp(r'пример|образец|например').hasMatch(lower), 10, 'Есть пример или образец', 'При необходимости добавь пример ожидаемого результата');
    check(RegExp(r'провер|критер|тест|готовност|приёмк|приемк').hasMatch(lower), 15, 'Есть критерии проверки', 'Определи критерии качества и проверки результата');
    check(RegExp(r'роль|ты —|ты ').hasMatch(lower), 10, 'Определена роль исполнителя', 'Назначь модели подходящую роль');
    check(RegExp(r'этап|шаг|последовательно|сначала|затем').hasMatch(lower), 10, 'Описан порядок работы', 'Разбей сложную работу на последовательные этапы');
    check(!RegExp(r'сделай всё|как-нибудь|что-нибудь|сам разберись').hasMatch(lower), 5, 'Формулировка достаточно конкретна', 'Замени расплывчатые формулировки проверяемыми требованиями');
    return PromptQualityReport(score: score.clamp(0, 100).toInt(), strengths: strengths, missing: missing);
  }
}
