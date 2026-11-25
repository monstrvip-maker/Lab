import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class WebResearchResult {
  const WebResearchResult({
    required this.title,
    required this.url,
    required this.snippet,
  });
  final String title;
  final String url;
  final String snippet;
}

/// API-key-free search using DuckDuckGo's public HTML/Lite endpoints.
/// Search availability depends on the provider's anti-bot limits and network access.
class WebResearchService {
  WebResearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<WebResearchResult>> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    Object? firstError;
    for (final endpoint in [
      Uri.https('html.duckduckgo.com', '/html/', {'q': normalized}),
      Uri.https('lite.duckduckgo.com', '/lite/', {'q': normalized}),
    ]) {
      try {
        final response = await _client.get(endpoint, headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/125.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'ru,en;q=0.8',
        }).timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          firstError ??= 'HTTP ${response.statusCode}';
          continue;
        }
        final document = html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
        final candidates = <WebResearchResult>[];

        for (final anchor in document.querySelectorAll('a.result__a, a.result-link')) {
          final title = anchor.text.trim();
          final href = _resolveResultUrl(anchor.attributes['href'] ?? '');
          if (title.isEmpty || href == null) continue;
          final parent = anchor.parent?.parent;
          final snippet = parent?.querySelector('.result__snippet, .result-snippet, td')?.text.trim() ?? '';
          candidates.add(WebResearchResult(title: title, url: href, snippet: snippet));
        }

        final unique = <String, WebResearchResult>{};
        for (final result in candidates) {
          unique.putIfAbsent(result.url, () => result);
        }
        if (unique.isNotEmpty) return unique.values.take(8).toList();
        firstError ??= 'Поисковая выдача не содержит результатов или сервис показал проверку робота.';
      } catch (error) {
        firstError ??= error;
      }
    }
    throw StateError(
      'Не удалось получить выдачу DuckDuckGo. Сервис может временно ограничивать автоматические запросы. '
      'Попробуйте позже или откройте сайт поиска в браузере. Подробности: $firstError',
    );
  }

  String? _resolveResultUrl(String href) {
    if (href.isEmpty) return null;
    final uri = Uri.tryParse(href);
    if (uri == null) return null;
    if (uri.host.contains('duckduckgo.com')) {
      final target = uri.queryParameters['uddg'];
      if (target != null) {
        final decoded = Uri.tryParse(target);
        if (decoded != null && (decoded.scheme == 'https' || decoded.scheme == 'http')) {
          return decoded.toString();
        }
      }
    }
    if (uri.scheme == 'https' || uri.scheme == 'http') return uri.toString();
    return null;
  }

  Future<String> readPage(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('Недопустимый адрес страницы.');
    }
    final response = await _client.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/125.0 Mobile Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.5',
    }).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw StateError('Не удалось прочитать страницу: HTTP ${response.statusCode}.');
    }
    final type = response.headers['content-type'] ?? '';
    final raw = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (type.contains('text/plain')) return _limit(raw);
    final document = html_parser.parse(raw);
    document.querySelectorAll('script,style,noscript,svg,nav,footer,header,form,aside').forEach((e) => e.remove());
    final title = document.querySelector('title')?.text.trim() ?? '';
    final main = document.querySelector('article') ?? document.querySelector('main') ?? document.body;
    final text = main?.text.replaceAll(RegExp(r'[ \\t]+'), ' ')
        .replaceAll(RegExp(r'\\n{3,}'), '\\n\\n').trim() ?? '';
    return _limit('${title.isEmpty ? '' : '$title\\n\\n'}$text');
  }

  String _limit(String value) {
    final text = value.trim();
    return text.length <= 4800 ? text : text.substring(0, 4800);
  }

  void dispose() => _client.close();
}
