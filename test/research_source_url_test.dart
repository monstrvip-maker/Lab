import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_lab_ai/ai/research/web_research_service.dart';

void main() {
  group('research source URL validation', () {
    test('rejects search engine homepages and result pages', () {
      expect(normalizeResearchSourceUrl('https://www.ya.ru/'), isEmpty);
      expect(normalizeResearchSourceUrl('https://yandex.ru/search/?text=prompt'), isEmpty);
      expect(normalizeResearchSourceUrl('https://www.google.com/search?q=prompt'), isEmpty);
      expect(normalizeResearchSourceUrl('https://html.duckduckgo.com/html/?q=prompt'), isEmpty);
      expect(isSearchEngineSourceUrl('https://www.ya.ru/'), isTrue);
    });

    test('keeps public content URLs and strips tracking parameters', () {
      final url = normalizeResearchSourceUrl('https://www.example.org/prompts?utm_source=test&gclid=123&id=7#top');
      expect(url, 'https://example.org/prompts?id=7');
      expect(isSearchEngineSourceUrl(url), isFalse);
    });

    test('rejects non-http and binary assets', () {
      expect(normalizeResearchSourceUrl('file:///tmp/prompt.txt'), isEmpty);
      expect(normalizeResearchSourceUrl('https://example.org/file.pdf'), isEmpty);
    });
  });
}
