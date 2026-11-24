import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        const Text('PROMPT LAB AI', style: TextStyle(fontSize: 12, letterSpacing: 2, color: Colors.white60)),
        const SizedBox(height: 5),
        const Text('Твоя AI-лаборатория', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
        const SizedBox(height: 22),
        Card(
          child: ListTile(
            leading: Icon(Icons.memory_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
            title: const Text('Локальный AI'),
            subtitle: const Text('Runtime пока не подключён — это следующий этап'),
          ),
        ),
        const SizedBox(height: 22),
        Text('Создать промт', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const TextField(
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Опиши задачу для будущего генератора промтов…',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Генератор подключим следующим этапом'),
        ),
        const SizedBox(height: 24),
        Text('Рабочее пространство', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        const _FeatureTile(icon: Icons.library_books_outlined, title: 'Библиотека промтов', subtitle: 'Оригиналы, версии и анализ'),
        const _FeatureTile(icon: Icons.psychology_alt_outlined, title: 'База знаний', subtitle: 'Методики и накопленный опыт'),
        const _FeatureTile(icon: Icons.hub_outlined, title: 'AI-агенты', subtitle: 'Роли, сценарии и задачи'),
        const _FeatureTile(icon: Icons.travel_explore_outlined, title: 'Центр исследований', subtitle: 'Источники и новые методики'),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}
