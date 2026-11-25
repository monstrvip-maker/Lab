import 'package:flutter/material.dart';
import '../ai/ai_screen.dart';
import '../agents/agents_screen.dart';
import '../knowledge/knowledge_screen.dart';
import '../prompts/prompt_builder_screen.dart';
import '../prompts/prompt_library_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _promptDraft = TextEditingController();
  @override
  void dispose() { _promptDraft.dispose(); super.dispose(); }

  void _openAi() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiScreen()));
  void _openAgents() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AgentsScreen()));
  void _openKnowledge() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KnowledgeScreen()));
  void _openPrompts() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PromptLibraryScreen()));
  void _buildPrompt() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PromptBuilderScreen(initialText: _promptDraft.text)));

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
    children: [
      const Text('PROMPT LAB AI', style: TextStyle(fontSize: 12, letterSpacing: 2, color: Colors.white60)),
      const SizedBox(height: 5),
      const Text('Твоя AI-лаборатория', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
      const SizedBox(height: 22),
      Card(child: ListTile(onTap: _openAi, leading: Icon(Icons.memory_rounded, color: Theme.of(context).colorScheme.primary, size: 32), title: const Text('Локальный AI'), subtitle: const Text('Открыть AI Studio и продолжить работу с Qwen'), trailing: const Icon(Icons.chevron_right))),
      const SizedBox(height: 22),
      Text('Создать промт', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      TextField(controller: _promptDraft, minLines: 3, maxLines: 5, decoration: const InputDecoration(hintText: 'Опиши задачу, для которой нужен качественный промт…')),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _buildPrompt, icon: const Icon(Icons.auto_awesome), label: const Text('Создать промт локально')),
      const SizedBox(height: 24),
      Text('Рабочее пространство', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      _FeatureTile(icon: Icons.library_books_outlined, title: 'Библиотека промтов', subtitle: 'Оригиналы, версии и анализ', onTap: _openPrompts),
      _FeatureTile(icon: Icons.psychology_alt_outlined, title: 'База знаний', subtitle: 'Локальные заметки, теги и поиск', onTap: _openKnowledge),
      _FeatureTile(icon: Icons.hub_outlined, title: 'AI-агенты', subtitle: 'Роли, сценарии и задачи', onTap: _openAgents),
      const _FeatureTile(icon: Icons.travel_explore_outlined, title: 'Центр исследований', subtitle: 'Раздел подготовлен; подключение источников — отдельный этап'),
    ],
  );
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.icon, required this.title, required this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    onTap: onTap,
    enabled: onTap != null,
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
  ));
}
