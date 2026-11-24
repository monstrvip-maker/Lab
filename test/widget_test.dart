import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_lab_ai/app/prompt_lab_app.dart';

void main() {
  testWidgets('Prompt Lab AI opens the main workspace', (tester) async {
    await tester.pumpWidget(const PromptLabApp());

    expect(find.text('Твоя AI-лаборатория'), findsOneWidget);
    expect(find.text('PROMPT LAB AI'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
  });
}
