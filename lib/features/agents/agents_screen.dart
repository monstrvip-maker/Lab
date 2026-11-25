import 'package:flutter/material.dart';

import '../ai/ai_screen.dart';

class AgentsScreen extends StatelessWidget {
  const AgentsScreen({super.key});

  static const _agents = <({IconData icon, String name, String description})>[
    (icon: Icons.route_outlined, name: 'Планировщик', description: 'Разбивает запрос на этапы, цели и последовательность действий.'),
    (icon: Icons.account_tree_outlined, name: 'Архитектор', description: 'Проектирует структуру решения, компоненты и связи.'),
    (icon: Icons.psychology_outlined, name: 'Эксперт', description: 'Готовит практическое решение по поставленной задаче.'),
    (icon: Icons.fact_check_outlined, name: 'Критик', description: 'Проверяет результат, ищет ошибки и противоречия.'),
  ];

  void _start(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiScreen(startInAgentMode: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI-агенты')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.hub_outlined, size: 36, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('Последовательная команда агентов', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'Четыре роли работают по очереди на одной загруженной локальной модели Qwen. '
                    'Каждая роль получает задачу и результаты предыдущих этапов.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final agent in _agents)
            Card(
              child: ListTile(
                leading: Icon(agent.icon, color: Theme.of(context).colorScheme.primary),
                title: Text(agent.name),
                subtitle: Text(agent.description),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Начать задачу с агентами'),
          ),
          const SizedBox(height: 12),
          Text(
            'Это первая версия оркестратора: роли выполняются последовательно одной моделью, '
            'а не отдельными независимыми AI-моделями. Для запуска Qwen должна быть загружена в AI Studio.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
