import 'package:flutter/material.dart';

import '../ai/model_manager_screen.dart';
import '../diagnostics/diagnostics_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Настройки')),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.memory),
              title: const Text('Модели AI'),
              subtitle: const Text('Импорт GGUF, загрузка и выгрузка Qwen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ModelManagerScreen()),
              ),
            ),
            const ListTile(
              leading: Icon(Icons.storage_outlined),
              title: Text('Хранилище'),
              subtitle: Text('База данных и резервные копии'),
            ),
            const ListTile(
              leading: Icon(Icons.notifications_outlined),
              title: Text('Уведомления'),
            ),
            const ListTile(
              leading: Icon(Icons.security_outlined),
              title: Text('Безопасность'),
            ),
            ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: const Text('Диагностика'),
              subtitle: const Text('Проверка локальных компонентов'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiagnosticsScreen())),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('О приложении'),
              subtitle: Text('Prompt Lab AI · 0.2.0'),
            ),
          ],
        ),
      );
}
