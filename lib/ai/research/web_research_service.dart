import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

class WebResearchService {
  WebResearchService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;

  static const _keyName = 'prompt_lab_brave_search_key';

  Future<void> saveApiKey(String key) async {
    final value = key.trim();
    if (value.isEmpty) {
      await _storage.delete(key: _keyName);
    } else {
      await _storage.write(key: _keyName, value: value);
    }
  }

  Future<bool> hasApiKey() async {
    final key = await _storage.read(key: _keyName);
    return key != null && key.trim().isNotEmpty;
  }

  Future<List<WebResearchResult>> search(String query) async {
    final key = await _storage.read(key: _keyName);
    if (key == null || key.trim().isEmpty) {
      throw StateError('Сначала добавьте ключ Brave Search API в настройках приложения.');
    }
    final uri = Uri.https('api.search.brave.com', '/res/v1/web/search', {
      'q': query.trim(),
      'count': '8',
      'country': 'DE',
      'search_lang': 'ru',
      'safesearch': 'moderate',
    });
    final response = await _client.get(uri, headers: {
      'Accept': 'application/json',
      'X-Subscription-Token': key,
    }).timeout(const Duration(seconds: 25));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('Brave отклонил ключ. Проверьте API-ключ и доступный тариф.');
    }
    if (response.statusCode == 429) {
      throw StateError('Лимит поисковых запросов исчерпан. Попробуйте позже.');
    }
    if (response.statusCode != 200) {
      throw StateError('Ошибка поиска: HTTP ${response.statusCode}.');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final web = data['web'] as Map<String, dynamic>?;
    final rows = web?['results'] as List<dynamic>? ?? const [];
    return rows.take(8).map((row) {
      final item = row as Map<String, dynamic>;
      return WebResearchResult(
        title: (item['title'] ?? 'Без названия').toString(),
        url: (item['url'] ?? '').toString(),
        snippet: (item['description'] ?? '').toString(),
      );
    }).where((item) => item.url.startsWith('https://') || item.url.startsWith('http://')).toList();
  }

  Future<String> readPage(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('Недопустимый адрес страницы.');
    }
    final response = await _client.get(uri, headers: {
      'User-Agent': 'PromptLabAI/1.0 (educational research reader)',
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
    final main = document.querySelector('article') ??
        document.querySelector('main') ??
        document.body;
    final text = main?.text.replaceAll(RegExp(r'[ \\t]+'), ' ')
        .replaceAll(RegExp(r'\\n{3,}'), '\\n\\n').trim() ?? '';
    return _limit('${title.isEmpty ? '' : '$title\\n\\n'}$text');
  }

  String _limit(String value) {
    final text = value.trim();
    if (text.length <= 4800) return text;
    return text.substring(0, 4800);
  }

  void dispose() => _client.close();
}
