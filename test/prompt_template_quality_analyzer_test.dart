import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_lab_ai/ai/prompts/prompt_template_quality_analyzer.dart';

void main() {
  group('PromptTemplateQualityAnalyzer', () {
    test('accepts a detailed reusable template', () {
      const prompt = '''
Роль: Ты — опытный аналитик и консультант.
Задача: Проанализируй [ДОКУМЕНТ] с учётом цели [ЦЕЛЬ] и контекста [КОНТЕКСТ].
Входные данные: используй только предоставленный текст и отмечай отсутствующие сведения.
Алгоритм:
1. Сначала выдели основные тезисы.
2. Затем проверь факты и противоречия.
3. После этого подготовь выводы и практические рекомендации.
Ограничения: не выдумывай данные; если информации недостаточно, прямо укажи это.
Формат результата: краткое резюме, таблица находок, риски и список рекомендаций.
Добавь обоснование каждого существенного вывода и отделяй факты от предположений.
''';
      final report = PromptTemplateQualityAnalyzer.analyze(prompt);
      expect(report.isUsable, isTrue);
      expect(report.score, greaterThanOrEqualTo(65));
      expect(report.issues, isEmpty);
    });

    test('rejects a short or vague prompt', () {
      final report = PromptTemplateQualityAnalyzer.analyze('Напиши хороший текст.');
      expect(report.isUsable, isFalse);
      expect(report.score, 0);
    });

    test('rejects content containing CJK characters', () {
      const prompt = '''
Роль: Ты — аналитик. Задача: проанализируй [ТЕКСТ] и [КОНТЕКСТ].
Входные данные: используй исходный материал.
Шаги: сначала прочитай, затем сравни, после этого объясни.
Ограничения: не выдумывай факты и укажи неопределённость.
Формат результата: выведи отчёт, выводы и рекомендации. 你好
''';
      final report = PromptTemplateQualityAnalyzer.analyze(prompt);
      expect(report.isUsable, isFalse);
      expect(report.score, 0);
      expect(report.issues.any((issue) => issue.contains('иероглифы')), isTrue);
    });
  });
}
