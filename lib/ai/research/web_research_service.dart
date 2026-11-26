import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

enum SearchProvider { all, github, google, yandex, duckDuckGo }

class WebResearchResult {
  const WebResearchResult({
    required this.title,
    required this.url,
    required this.snippet,
    required this.provider,
  });
  final String title;
  final String url;
  final String snippet;
  final String provider;
}

class WebResearchService {
  WebResearchService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/125.0 Mobile Safari/537.36';

  Future<List<WebResearchResult>> search(
    String query, {
    SearchProvider provider = SearchProvider.all,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final providers = provider == SearchProvider.all
        ? [SearchProvider.github]
        : [provider];
    final collected = <String, WebResearchResult>{};
    final errors = <String>[];

    // Search engines are queried one by one: one blocked engine must not prevent
    // results from the remaining providers.
    for (final engine in providers) {
      try {
        final results = engine == SearchProvider.github
            ? await _searchGitHubWithFallback(q)
            : await _searchOne(q, engine);
        for (final result in results) {
          collected.putIfAbsent(result.url, () => result);
        }
      } catch (e) {
        errors.add('${_label(engine)}: $e');
      }
    }
    if (collected.isEmpty) {
      throw StateError(errors.isEmpty
          ? 'Поисковики не вернули результатов. Возможно, сработала антибот-защита.'
          : 'Не удалось получить выдачу. ${errors.join(' | ')}');
    }
    final ranked = collected.values.toList()
      ..sort((a, b) => _relevanceScore(b, q).compareTo(_relevanceScore(a, q)));
    return ranked.take(18).toList();
  }

  Future<List<WebResearchResult>> _searchGitHubWithFallback(String query) async {
    try {
      final github = await _searchGitHub(query);
      if (github.isNotEmpty) return github;
    } catch (_) {
      // Continue to the independent Hugging Face public catalog.
    }
    return _searchHuggingFace(query);
  }

  Future<List<WebResearchResult>> _searchHuggingFace(String query) async {
    final uri = Uri.https('huggingface.co', '/api/datasets', {
      'search': 'prompt',
      'limit': '20',
      'sort': 'downloads',
      'direction': '-1',
    });
    final response = await _client.get(uri, headers: {
      'Accept': 'application/json',
      'User-Agent': 'PromptLabAI-PromptResearch/1.0',
    }).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Публичный каталог Hugging Face недоступен (HTTP ${response.statusCode}).');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (decoded is! List) {
      throw const FormatException('Hugging Face API вернул неожиданный формат.');
    }
    final results = <WebResearchResult>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final searchable = id.toLowerCase();
      if (!RegExp(r'prompt|prompts|instruction|chatbot', caseSensitive: false).hasMatch(searchable)) continue;
      results.add(WebResearchResult(
        title: 'Hugging Face · $id',
        url: Uri.https('huggingface.co', '/datasets/$id/raw/main/README.md').toString(),
        snippet: 'Публичная карточка датасета, найденная через Hugging Face API',
        provider: 'Hugging Face API',
      ));
      if (results.length >= 8) break;
    }
    if (results.isEmpty) {
      throw StateError('Hugging Face не нашёл датасетов с явными признаками prompt.');
    }
    return results;
  }

  Future<List<WebResearchResult>> _searchGitHub(String query) async {
    final focusedQuery = _githubPromptQuery(query);
    final uri = Uri.https('api.github.com', '/search/repositories', {
      'q': focusedQuery,
      'sort': 'stars',
      'order': 'desc',
      'per_page': '12',
    });
    final response = await _client.get(uri, headers: {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'PromptLabAI-PromptResearch/1.0',
    }).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw StateError('GitHub API временно ограничил запросы (HTTP ${response.statusCode}).');
      }
      throw StateError('GitHub API HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (decoded is! Map<String, dynamic> || decoded['items'] is! List) {
      throw const FormatException('GitHub API вернул неожиданный формат.');
    }
    final results = <WebResearchResult>[];
    for (final item in decoded['items'] as List) {
      if (item is! Map<String, dynamic>) continue;
      final fullName = item['full_name']?.toString() ?? '';
      final branch = item['default_branch']?.toString() ?? 'main';
      final htmlUrl = item['html_url']?.toString() ?? '';
      final description = item['description']?.toString() ?? '';
      if (fullName.isEmpty || htmlUrl.isEmpty) continue;
      final searchable = '$fullName $description'.toLowerCase();
      if (!RegExp(r'prompt|prompts|шаблон|промт|промпт|awesome', caseSensitive: false).hasMatch(searchable)) continue;
      final parts = fullName.split('/');
      if (parts.length != 2) continue;
      final readmeUrl = Uri.https(
        'raw.githubusercontent.com',
        '/${parts[0]}/${parts[1]}/$branch/README.md',
      ).toString();
      results.add(WebResearchResult(
        title: fullName,
        url: readmeUrl,
        snippet: description,
        provider: 'GitHub API',
      ));
    }
    if (results.isEmpty) {
      throw StateError('GitHub API не нашёл публичных репозиториев с признаками prompt templates.');
    }
    return results;
  }

  String _githubPromptQuery(String query) {
    final terms = query
        .replaceAll(RegExp(r'["()]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty && !{
          'site:github.com', 'prompt', 'prompts', 'template', 'templates',
          'examples', 'reusable', 'system', 'library',
        }.contains(word.toLowerCase()))
        .take(8)
        .join(' ');
    final focused = terms.isEmpty ? 'prompt templates' : terms;
    return '$focused prompt in:name,description,readme';
  }

  Future<List<WebResearchResult>> _searchOne(String query, SearchProvider engine, {int candidateOffset = 0}) async {
    late final List<Uri> candidates;
    switch (engine) {
      case SearchProvider.github:
        throw ArgumentError('GitHub search uses the public API');
      case SearchProvider.google:
        candidates = [
          Uri.https('www.google.com', '/search', {'q': query, 'num': '10', 'hl': 'ru', 'udm': '14'}),
          Uri.https('www.google.com', '/search', {'q': query, 'num': '10', 'hl': 'ru'}),
          Uri.https('google.com', '/search', {'q': query, 'num': '10', 'hl': 'ru'}),
        ];
      case SearchProvider.yandex:
        candidates = [
          Uri.https('yandex.com', '/search/', {'text': query, 'lang': 'ru'}),
          Uri.https('yandex.ru', '/search/', {'text': query, 'lr': '213'}),
        ];
      case SearchProvider.duckDuckGo:
        candidates = [
          Uri.https('html.duckduckgo.com', '/html/', {'q': query}),
          Uri.https('lite.duckduckgo.com', '/lite/', {'q': query}),
        ];
      case SearchProvider.all:
        throw ArgumentError('Select a concrete search engine');
    }

    http.Response? response;
    Object? lastError;
    for (final uri in candidates.skip(candidateOffset)) {
      try {
        final attempt = await _client.get(uri, headers: {
          'User-Agent': _userAgent,
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'ru,en;q=0.8',
        }).timeout(const Duration(seconds: 20));
        if (attempt.statusCode == 200) {
          response = attempt;
          break;
        }
        lastError = StateError(
          attempt.statusCode == 202 || attempt.statusCode == 403 || attempt.statusCode == 429
              ? 'Поисковик временно ограничил автоматический поиск (HTTP ${attempt.statusCode}).'
              : 'HTTP ${attempt.statusCode}',
        );
      } catch (error) {
        lastError = error;
      }
    }
    if (response == null) {
      throw StateError('${lastError ?? 'Поисковик не ответил'}. Попробуйте другой источник или откройте поисковик в браузере.');
    }
    final document = html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
    document.querySelectorAll('script,style,noscript,svg,nav,footer,header,form').forEach((e) => e.remove());

    final results = <WebResearchResult>[];
    final seen = <String>{};
    // Avoid CSS :has(): the Dart html parser does not implement it.
    // Parse anchors structurally so minor SERP class changes do not break Google.
    final anchors = document.querySelectorAll('a[href]');
    for (final anchor in anchors) {
      final href = anchor.attributes['href'] ?? '';
      final heading = anchor.querySelector('h3');
      final title = switch (engine) {
        SearchProvider.github => '',
        SearchProvider.google => _firstNonEmpty([
            heading?.text,
            anchor.querySelector('.LC20lb, h2, h3')?.text,
            anchor.text,
          ]),
        SearchProvider.yandex => _firstNonEmpty([
            anchor.querySelector('.OrganicTitle, .OrganicTitle-Link, h2, h3')?.text,
            anchor.attributes['aria-label'],
            anchor.text,
          ]),
        SearchProvider.duckDuckGo => _firstNonEmpty([
            anchor.querySelector('.result__title')?.text,
            anchor.text,
          ]),
        SearchProvider.all => '',
      };
      final url = _resolveUrl(href, engine, base: response.request?.url);
      if (title.trim().length < 4 ||
          title.trim().length > 180 ||
          url == null ||
          !seen.add(url) ||
          isSearchEngineSourceUrl(url)) continue;
      final parent = anchor.parent?.parent ?? anchor.parent;
      final snippet = _firstNonEmpty([
        parent?.querySelector(
          '.VwiC3b, .IsZvec, .result__snippet, .OrganicText, .TextContainer, .text-container, .result__body',
        )?.text,
        parent?.text,
      ]);
      results.add(WebResearchResult(
        title: title.replaceAll(RegExp(r'\s+'), ' '),
        url: url,
        snippet: snippet,
        provider: _label(engine),
      ));
    }
    if (results.isEmpty && candidateOffset + 1 < candidates.length) {
      return _searchOne(query, engine, candidateOffset: candidateOffset + 1);
    }
    if (results.isEmpty) {
      throw StateError('Выдача пуста или поисковик показал CAPTCHA/антибот-проверку.');
    }
    return results.take(10).toList();
  }

  int _relevanceScore(WebResearchResult result, String query) {
    final stopWords = <String>{
      'для', 'или', 'как', 'что', 'это', 'the', 'and', 'for', 'with',
      'best', 'guide', 'tutorial', 'documentation', 'пример', 'практика',
    };
    final terms = query.toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((word) => word.length > 2 && !stopWords.contains(word))
        .toSet();
    final title = result.title.toLowerCase();
    final snippet = result.snippet.toLowerCase();
    var score = 0;
    for (final term in terms) {
      if (title.contains(term)) score += 4;
      if (snippet.contains(term)) score += 1;
    }
    final host = Uri.tryParse(result.url)?.host.toLowerCase() ?? '';
    if (host.endsWith('.gov') || host.endsWith('.edu') ||
        host.contains('arxiv.org') || host.contains('github.com') ||
        host.contains('developer.android.com') || host.contains('docs.flutter.dev')) {
      score += 2;
    }
    if (title.length < 8) score -= 3;
    if (snippet.length < 35) score -= 1;
    return score;
  }

  String _firstNonEmpty(List<String?> values) => values
      .map((value) => value?.trim() ?? '')
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');

  String? _resolveUrl(String href, SearchProvider engine, {Uri? base}) {
    if (href.isEmpty) return null;
    var uri = Uri.tryParse(href);
    if (uri != null && !uri.hasScheme && base != null) uri = base.resolveUri(uri);
    if (uri == null) return null;
    if (engine == SearchProvider.duckDuckGo && uri.host.contains('duckduckgo.com')) {
      final target = uri.queryParameters['uddg'];
      if (target != null) return _validHttp(target);
    }
    if (engine == SearchProvider.google && uri.path == '/url') {
      final target = uri.queryParameters['q'];
      if (target != null) return _validHttp(target);
    }
    if (engine == SearchProvider.yandex && uri.host.contains('yandex')) {
      final target = uri.queryParameters['url'];
      if (target != null) return _validHttp(target);
    }
    return _validHttp(uri.toString());
  }

  String? _validHttp(String value) {
    final normalized = normalizeResearchSourceUrl(value);
    return normalized.isEmpty || isSearchEngineSourceUrl(normalized) ? null : normalized;
  }

  String _label(SearchProvider engine) => switch (engine) {
    SearchProvider.github => 'GitHub API',
    SearchProvider.google => 'Google',
    SearchProvider.yandex => 'Яндекс',
    SearchProvider.duckDuckGo => 'DuckDuckGo',
    SearchProvider.all => 'Публичные API',
  };

  Future<String> readPage(String url) async {
    final normalizedUrl = normalizeResearchSourceUrl(url);
    if (normalizedUrl.isEmpty || isSearchEngineSourceUrl(normalizedUrl)) {
      throw const FormatException('Адрес не является публичной страницей с материалом.');
    }
    final uri = Uri.parse(normalizedUrl);

    Object? directError;
    try {
      final response = await _client.get(uri, headers: {
        'User-Agent': _userAgent,
        'Accept': 'text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.5',
        'Accept-Language': 'ru,en;q=0.8',
      }).timeout(const Duration(seconds: 18));
      if (response.statusCode >= 200 && response.statusCode < 400) {
        final extracted = _extractPageText(response);
        if (extracted.length >= 160) return _limit(extracted);
        directError = StateError('На странице недостаточно основного текста для исследования.');
      } else {
        directError = StateError('HTTP ${response.statusCode}');
      }
    } catch (error) {
      directError = error;
    }

    // Many public sites reject lightweight clients (403/429) or render the
    // article client-side. Jina Reader is a public text-reader fallback; it
    // does not bypass authentication or CAPTCHA and only reads public URLs.
    try {
      final readerUri = Uri.https('r.jina.ai', '/${uri.scheme}://${uri.authority}${uri.path}', uri.hasQuery ? uri.queryParameters : null);
      final readerResponse = await _client.get(readerUri, headers: {
        'User-Agent': 'PromptLabAI/1.0 (public-page text extraction)',
        'Accept': 'text/plain',
      }).timeout(const Duration(seconds: 25));
      if (readerResponse.statusCode >= 200 && readerResponse.statusCode < 300) {
        final text = utf8.decode(readerResponse.bodyBytes, allowMalformed: true).trim();
        if (text.length >= 160) return _limit(text);
        throw StateError('Reader вернул слишком короткий текст.');
      }
      throw StateError('Reader HTTP ${readerResponse.statusCode}');
    } catch (readerError) {
      final readerMessage = readerError.toString();
      if (readerMessage.contains('451')) {
        throw StateError(
          'Источник недоступен для чтения (HTTP 451). Не повторяю запрос к этому адресу; перехожу к следующему источнику.',
        );
      }
      throw StateError(
        'Не удалось прочитать публичную страницу. Прямой запрос: $directError; '
        'текстовый reader: $readerError',
      );
    }
  }

  String _extractPageText(http.Response response) {
    final type = response.headers['content-type'] ?? '';
    final raw = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (type.contains('text/plain') || !type.contains('html')) return raw.trim();
    final document = html_parser.parse(raw);
    document.querySelectorAll('script,style,noscript,svg,nav,footer,header,form,aside,iframe').forEach((e) => e.remove());
    final title = document.querySelector('title')?.text.trim() ?? '';
    final main = document.querySelector('article') ??
        document.querySelector('main') ??
        document.querySelector('[role=main]') ??
        document.body;
    final paragraphs = main?.querySelectorAll('p,li,h1,h2,h3,blockquote,pre')
        .map((element) => element.text.trim())
        .where((value) => value.length > 35)
        .toList() ?? const <String>[];
    final bodyText = paragraphs.isNotEmpty
        ? paragraphs.join('\n\n')
        : (main?.text ?? '');
    final text = bodyText
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return '${title.isEmpty ? '' : '$title\n\n'}$text';
  }

  String _limit(String value) {
    final text = value.trim();
    // Keep the source excerpt small enough for a 2K-token mobile context.
    return text.length <= 2200 ? text : text.substring(0, 2200);
  }

  void dispose() => _client.close();
}


/// Returns a canonical public content URL, excluding search engines,
/// social networks, tracking redirects and non-page assets.
String normalizeResearchSourceUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return '';
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  const blockedHosts = {
    'google.com', 'google.ru', 'google.de', 'google.co.uk',
    'yandex.ru', 'yandex.com', 'ya.ru', 'yastatic.net',
    'duckduckgo.com', 'facebook.com', 'instagram.com',
    'tiktok.com', 'youtube.com', 'm.youtube.com',
  };
  if (host.isEmpty ||
      blockedHosts.any((blocked) => host == blocked || host.endsWith('.$blocked')) ||
      host.startsWith('accounts.') ||
      uri.path.toLowerCase().endsWith('.pdf') ||
      uri.path.toLowerCase().endsWith('.jpg') ||
      uri.path.toLowerCase().endsWith('.jpeg') ||
      uri.path.toLowerCase().endsWith('.png') ||
      uri.path.toLowerCase().endsWith('.zip')) return '';
  final query = Map<String, String>.from(uri.queryParameters)
    ..removeWhere((key, _) =>
        key.toLowerCase().startsWith('utm_') ||
        {'yclid', 'gclid', 'fbclid', 'ref', 'from'}.contains(key.toLowerCase()));
  return uri.removeFragment().replace(host: host, queryParameters: query.isEmpty ? null : query).toString();
}


/// Search engine result pages are not source documents and must never be
/// passed to the page reader or counted as prompt sources.
bool isSearchEngineSourceUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return true;
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  final isGoogle = host.startsWith('google.') || host.contains('.google.');
  final isYandex = host == 'ya.ru' || host.endsWith('.ya.ru') ||
      host.startsWith('yandex.') || host.contains('.yandex.') ||
      host.endsWith('.yastatic.net');
  final isDuckDuckGo = host == 'duckduckgo.com' || host.endsWith('.duckduckgo.com');
  final isOtherSearch = host == 'bing.com' || host.endsWith('.bing.com') ||
      host == 'ecosia.org' || host.endsWith('.ecosia.org') ||
      host.startsWith('search.yahoo.');
  return isGoogle || isYandex || isDuckDuckGo || isOtherSearch;
}
