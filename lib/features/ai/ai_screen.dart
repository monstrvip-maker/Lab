import 'package:flutter/material.dart';

class AiScreen extends StatelessWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('AI Studio')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            _AiModule(icon: Icons.auto_awesome, title: 'Генератор промтов', subtitle: 'Создание, анализ и улучшение'),
            _AiModule(icon: Icons.groups_2_outlined, title: 'Агенты', subtitle: 'Planner, Expert, Critic и другие роли'),
            _AiModule(icon: Icons.school_outlined, title: 'Обучение и знания', subtitle: 'Извлечение методик и журнал обучения'),
            _AiModule(icon: Icons.manage_search_outlined, title: 'Исследования', subtitle: 'Поиск и анализ открытых источников'),
          ],
        ),
      );
}

class _AiModule extends StatelessWidget {
  const _AiModule({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}
