import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_lab_ai/ai/prompts/prompt_extraction_parser.dart';

void main() {
  group('PromptExtractionParser', () {
    test('parses the Russian labelled response', () {
      const response = 'ПРОМТ_НАЗВАНИЕ: Анализ документа\nПРОМТ_ШАБЛОН:\nРоль: Ты — аналитик. Задача: проанализируй [ТЕКСТ] и [ЦЕЛЬ]. Входные данные: используй [КОНТЕКСТ]. Шаги: сначала изучи, затем сравни и проверь. Ограничения: не выдумывай факты. Формат результата: отчёт с выводами и рекомендациями.\nПРИМЕНЕНИЕ: Для анализа.';
      final parsed = PromptExtractionParser.parse(response);
      expect(parsed.title, 'Анализ документа');
      expect(parsed.template, contains('Роль:'));
      expect(parsed.template, isNot(contains('ПРИМЕНЕНИЕ:')));
    });

    test('accepts English template labels', () {
      const response = 'PROMPT TITLE: Research helper\nPROMPT TEMPLATE:\nYou are an analyst. Your task: analyze [INPUT]. First review the evidence, then compare it. Do not invent facts. Output: a structured report.';
      final parsed = PromptExtractionParser.parse(response);
      expect(parsed.title, 'Research helper');
      expect(parsed.template, contains('You are an analyst'));
    });

    test('rejects unlabelled explanatory prose', () {
      final parsed = PromptExtractionParser.parse(
        'На этой странице собраны полезные рекомендации по работе с документами. '
        'Автор рассказывает о нескольких подходах, приводит примеры и объясняет '
        'почему важно проверять итоговый результат перед публикацией.',
      );
      expect(parsed.template, isEmpty);
    });

    test('accepts an unlabelled response that clearly starts as a prompt', () {
      const response = 'Ты — опытный аналитик. Проанализируй [ДОКУМЕНТ] и [ЦЕЛЬ]. '
          'Входные данные: используй [КОНТЕКСТ]. Сначала выдели тезисы, затем сравни '
          'факты. Не выдумывай сведения. Формат результата: структурированный отчёт '
          'с выводами, таблицей и рекомендациями.';
      final parsed = PromptExtractionParser.parse(response);
      expect(parsed.template, startsWith('Ты —'));
    });

    test('rejects pages without suitable prompts', () {
      final parsed = PromptExtractionParser.parse('ИСТОЧНИК_НЕПОДХОДИТ');
      expect(parsed.template, isEmpty);
    });
  });
}
