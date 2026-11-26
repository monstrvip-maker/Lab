import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:prompt_lab_ai/ai/research/web_research_service.dart';

void main() {
  group('GitHub prompt research API', () {
    test('searches public repositories and returns raw README sources', () async {
      late Uri requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode({
            'items': [
              {
                'full_name': 'sample/awesome-prompts',
                'default_branch': 'main',
                'html_url': 'https://github.com/sample/awesome-prompts',
                'description': 'A curated prompt templates library',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = WebResearchService(client: client);
      final results = await service.search(
        'document analysis prompt templates',
        provider: SearchProvider.all,
      );
      expect(requested.host, 'api.github.com');
      expect(requested.path, '/search/repositories');
      expect(requested.queryParameters['q'], contains('prompt'));
      expect(results, hasLength(1));
      expect(results.single.provider, 'GitHub API');
      expect(results.single.url,
          'https://raw.githubusercontent.com/sample/awesome-prompts/main/README.md');
      service.dispose();
    });

    test('reports when GitHub returns no matching repositories', () async {
      final client = MockClient((request) async => http.Response(
        jsonEncode({'items': []}),
        200,
        headers: {'content-type': 'application/json'},
      ));
      final service = WebResearchService(client: client);
      await expectLater(
        service.search('prompt templates', provider: SearchProvider.all),
        throwsA(isA<StateError>()),
      );
      service.dispose();
    });;
  });
}
