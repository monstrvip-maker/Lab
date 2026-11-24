import 'package:flutter/material.dart';

import '../prompts/prompt_library_screen.dart';

class AiScreen extends StatelessWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('AI Studio')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _AiModule(
              icon: Icons.library_books_outlined,
              title: 'Библиотека промтов',
              subtitle: 'Сохранение оригиналов и избранное',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PromptLibraryScreen()),
              ),
            ),
            const SizedBox(height: 12),
            const _AiModule(icon: Icons.auto_awesome, title: 'Генератор промтов', subtitle: 'Подключим после локального AI Runtime'),
            const SizedBox(height: 12),
            const _AiModule(icon: Icons.groups_2_outlined, title: 'Агенты', subtitle: 'Planner, Expert, Critic и другие роли'),
            const SizedBox(height: 12),
            const _AiModule(icon: Icons.school_outlined, title: 'Обучение и знания', subtitle: 'Следующий этап разработки'),
            const SizedBox(height: 12),
            const _AiModule(icon: Icons.manage_search_outlined, title: 'Исследования', subtitle: 'Поиск и анализ открытых источников'),
          ],
        ),
      );
}

class _AiModule extends StatelessWidget {
  const _AiModule({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
