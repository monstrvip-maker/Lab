class PromptExtractionResult {
  const PromptExtractionResult({required this.title, required this.template});
  final String title;
  final String template;
}

/// Parses common local-model output variants. Quality validation remains separate.
class PromptExtractionParser {
  static PromptExtractionResult parse(String response) {
    final cleaned = response.replaceAll(RegExp(r'\x60\x60\x60(?:[a-zA-Z]+)?'), '').replaceAll('\r', '').trim();
    final rejected = RegExp(r'ИСТОЧНИК_НЕПОДХОДИТ|НЕТ\s+ПОДХОДЯЩИХ\s+ПРОМТОВ|NO\s+SUITABLE\s+PROMPTS', caseSensitive: false).hasMatch(cleaned);
    if (cleaned.isEmpty || rejected) return const PromptExtractionResult(title: '', template: '');
    final titleMatch = RegExp(r'(?:ПРОМТ[_\s]*НАЗВАНИЕ|НАЗВАНИЕ\s+ПРОМТА|PROMPT[_\s]*TITLE|TITLE)\s*:\s*([\s\S]*?)(?=\n|ПРОМТ|PROMPT|$)', caseSensitive: false).firstMatch(cleaned);
    final templateMatch = RegExp(r'(?:ПРОМТ[_\s]*ШАБЛОН|ШАБЛОН\s+ПРОМТА|ТЕКСТ\s+ПРОМТА|PROMPT[_\s]*TEMPLATE|PROMPT\s+TEXT|TEMPLATE)\s*:\s*([\s\S]*?)(?=\n\s*(?:ПРИМЕНЕНИЕ|КАК\s+ИСПОЛЬЗОВАТЬ|APPLICATION|USE\s*CASE|ПРОМТ[_\s]*НАЗВАНИЕ|PROMPT[_\s]*TITLE)\s*:|$)', caseSensitive: false).firstMatch(cleaned);
    var title = titleMatch?.group(1)?.trim() ?? '';
    var template = templateMatch?.group(1)?.trim() ?? '';
    if (template.isEmpty) {
      template = cleaned.replaceAll(RegExp(r'^(?:вот\s+(?:готовый\s+)?промт|готовый\s+шаблон|here\s+is\s+(?:the\s+)?prompt)\s*:\s*', caseSensitive: false, multiLine: true), '').trim();
    }
    template = template.replaceAll(RegExp(r'^\s*["“”]+|["“”]+\s*$'), '').trim();
    title = title.replaceAll(RegExp(r'^\s*["“”]+|["“”]+\s*$'), '').trim();
    if (title.toUpperCase() == 'НЕТ' || title.toUpperCase() == 'NONE') title = '';
    return PromptExtractionResult(title: title, template: template);
  }
}
