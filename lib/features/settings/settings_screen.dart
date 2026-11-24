import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Настройки')),
        body: ListView(
          children: const [
            ListTile(leading: Icon(Icons.memory), title: Text('Модели AI'), subtitle: Text('Менеджер Qwen и Vision')),
            ListTile(leading: Icon(Icons.storage_outlined), title: Text('Хранилище'), subtitle: Text('База данных и резервные копии')),
            ListTile(leading: Icon(Icons.notifications_outlined), title: Text('Уведомления')),
            ListTile(leading: Icon(Icons.security_outlined), title: Text('Безопасность')),
            ListTile(leading: Icon(Icons.monitor_heart_outlined), title: Text('Диагностика')),
            ListTile(leading: Icon(Icons.info_outline), title: Text('О приложении')),
          ],
        ),
      );
}
