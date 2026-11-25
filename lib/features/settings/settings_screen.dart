import 'package:flutter/material.dart';

import '../ai/model_manager_screen.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../workspace/workspace_tools_screen.dart';
import '../../data/repositories/backup_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _chooseBackupFolder(BuildContext context) async {
    try {
      final folder = await BackupRepository().chooseBackupFolder();
      if (!context.mounted || folder == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Автосохранение включено. Копия создаётся при сворачивании приложения.')),
      );
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось выбрать папку: $error')));
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    try {
      final count = await BackupRepository().restoreLatestFromFolder();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Восстановление завершено. Записей обработано: $count. Перезапустите приложение.')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось восстановить данные: $error')));
    }
  }

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
            ListTile(
              leading: const Icon(Icons.folder_copy_outlined),
              title: const Text('Автокопия в Documents'),
              subtitle: const Text('Выбрать папку для автоматического сохранения данных'),
              onTap: () => _chooseBackupFolder(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings_backup_restore),
              title: const Text('Восстановить данные из Documents'),
              subtitle: const Text('После переустановки выберите папку с резервными копиями'),
              onTap: () => _restoreBackup(context),
            ),
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: const Text('Хранилище и резервные копии'),
              subtitle: const Text('Экспорт, импорт и перенос базы знаний'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkspaceToolsScreen())),
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
