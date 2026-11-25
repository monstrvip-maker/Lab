import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../data/repositories/backup_repository.dart';
import '../../data/repositories/workspace_repository.dart';

class WorkspaceToolsScreen extends StatefulWidget {
  const WorkspaceToolsScreen({super.key});
  @override
  State<WorkspaceToolsScreen> createState() => _WorkspaceToolsScreenState();
}

class _WorkspaceToolsScreenState extends State<WorkspaceToolsScreen> {
  final _backup = BackupRepository();
  final _workspace = WorkspaceRepository();
  bool _busy = false;
  String _status = 'Данные хранятся локально на устройстве. Резервная копия содержит проекты, заметки, промты, версии и память.';

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final path = await _backup.saveBackup();
      if (mounted) setState(() => _status = path == null ? 'Сохранение отменено.' : 'Резервная копия сохранена: $path');
    } catch (e) { if (mounted) setState(() => _status = 'Ошибка экспорта: $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _import() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Импортировать резервную копию?'),
      content: const Text('Данные будут добавлены к текущим. Существующие записи не удаляются. Повторный импорт может создать дубликаты записей без совпадающих ID.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Продолжить'))],
    ));
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      final count = await _backup.importSelectedFile();
      if (mounted) setState(() => _status = count == 0 ? 'Импорт отменён или файл пуст.' : 'Импортировано записей: $count. Перезапусти соответствующие разделы для обновления списка.');
    } catch (e) { if (mounted) setState(() => _status = 'Импорт не выполнен: $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _importKnowledge() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'md'], withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    final content = utf8.decode(file.bytes!, allowMalformed: true).trim();
    if (content.isEmpty) { setState(() => _status = 'В выбранном файле нет текста.'); return; }
    setState(() => _busy = true);
    try {
      final title = file.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      await _workspace.saveNote(title: title, content: content, tags: 'импорт, документ');
      if (mounted) setState(() => _status = 'Документ «$title» импортирован в базу знаний.');
    } catch (e) { if (mounted) setState(() => _status = 'Ошибка импорта документа: $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Инструменты рабочего пространства')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Резервное копирование', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Переноси свою локальную базу между устройствами. Экспортируется JSON-файл; импорт добавляет записи и не стирает текущие данные.'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: _busy ? null : _export, icon: const Icon(Icons.download), label: const Text('Экспортировать')),
          OutlinedButton.icon(onPressed: _busy ? null : _import, icon: const Icon(Icons.upload_file), label: const Text('Импортировать')),
        ]),
      ]))),
      const SizedBox(height: 8),
      Card(child: ListTile(leading: const Icon(Icons.article_outlined), title: const Text('Импорт документов в базу знаний'), subtitle: const Text('Текстовые файлы TXT и Markdown'), trailing: const Icon(Icons.chevron_right), onTap: _busy ? null : _importKnowledge)),
      const SizedBox(height: 12),
      if (_busy) const LinearProgressIndicator(),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: SelectableText(_status))),
      const SizedBox(height: 12),
      Text('Ограничения', style: Theme.of(context).textTheme.titleMedium),
      const Text('Импорт документов пока сохраняет текст как заметку; PDF/DOCX, OCR и разбиение больших файлов на фрагменты требуют отдельного парсера. Резервная копия не включает файлы моделей GGUF, поскольку они могут занимать несколько гигабайт.'),
    ]),
  );
}
