import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

/// Portable JSON backup. Only app-owned tables are exported/imported.
class BackupRepository {
  static const _tables = <String>[
    'projects', 'project_tasks', 'prompts', 'prompt_versions',
    'knowledge_notes', 'memory_items', 'memory_feedback',
    'task_checkpoints', 'prompt_tests', 'knowledge_sources', 'agent_runs',
    'learning_state', 'learning_history', 'task_dependencies',
    'knowledge_documents', 'knowledge_chunks', 'learning_queue',
  ];

  static const _folderKey = 'prompt_lab_backup_folder';

  /// Lets Android's system folder picker grant access to Documents/PromptLabAI.
  Future<String?> chooseBackupFolder() async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите папку Documents/PromptLabAI для резервных копий',
    );
    if (selected == null || selected.isEmpty) return null;
    final folder = path.basename(selected).toLowerCase() == 'promptlabai'
        ? selected
        : path.join(selected, 'PromptLabAI');
    final directory = Directory(folder);
    if (!await directory.exists()) await directory.create(recursive: true);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_folderKey, folder);
    return selected;
  }

  Future<String?> configuredFolder() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_folderKey);
  }

  /// Writes a timestamped snapshot. Called when the app is backgrounded.
  Future<String?> autoBackup() async {
    final folder = await configuredFolder();
    if (folder == null || folder.isEmpty) return null;
    final directory = Directory(folder);
    if (!await directory.exists()) {
      throw StateError('Папка резервного копирования недоступна. Выберите её снова.');
    }
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File(path.join(folder, 'prompt_lab_$stamp.json'));
    await file.writeAsBytes(await exportBytes(), flush: true);
    // Retain the five newest snapshots to limit storage use.
    final backups = directory.listSync().whereType<File>()
      .where((item) => path.basename(item.path).startsWith('prompt_lab_') && item.path.endsWith('.json')).toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final old in backups.skip(5)) {
      try { await old.delete(); } catch (_) {}
    }
    return file.path;
  }

  Future<int> restoreOrCreateFromFolder() async {
    final folder = await configuredFolder();
    if (folder == null || folder.isEmpty) {
      throw StateError('Сначала выберите папку резервной копии в Documents.');
    }
    final directory = Directory(folder);
    if (!await directory.exists()) throw StateError('Папка резервной копии недоступна.');
    final backups = directory.listSync().whereType<File>()
      .where((item) => path.basename(item.path).startsWith('prompt_lab_') && item.path.endsWith('.json')).toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    if (backups.isEmpty) {
      await autoBackup();
      return 0;
    }
    return importBackup(await backups.first.readAsBytes());
  }

  /// After reinstall, Android requires the user to grant the folder again.
  /// Once granted, the newest backup is restored automatically by this method.
  Future<int> restoreLatestFromFolder() async {
    final folder = await configuredFolder();
    if (folder == null || folder.isEmpty) {
      throw StateError('Сначала выберите папку резервной копии в Documents.');
    }
    final directory = Directory(folder);
    if (!await directory.exists()) {
      throw StateError('Папка недоступна. После переустановки выберите Documents/PromptLabAI ещё раз.');
    }
    final backups = directory.listSync().whereType<File>()
      .where((item) => path.basename(item.path).startsWith('prompt_lab_') && item.path.endsWith('.json')).toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    if (backups.isEmpty) throw StateError('В выбранной папке нет резервных копий Prompt Lab AI.');
    return importBackup(await backups.first.readAsBytes());
  }

  Future<Uint8List> exportBytes() async {
    final db = await AppDatabase.instance.database;
    final payload = <String, Object?>{
      'format': 'prompt-lab-backup',
      'schema': 6,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': <String, Object?>{},
      'preferences': <String, Object?>{},
    };
    final data = <String, Object?>{};
    for (final table in _tables) {
      data[table] = await db.query(table);
    }
    payload['tables'] = data;
    final preferences = await SharedPreferences.getInstance();
    payload['preferences'] = {for (final key in preferences.getKeys()) key: preferences.get(key)};
    return Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)));
  }

  Future<String?> saveBackup() async {
    final bytes = await exportBytes();
    return FilePicker.platform.saveFile(
      dialogTitle: 'Сохранить резервную копию Prompt Lab AI',
      fileName: 'prompt_lab_backup_${DateTime.now().toIso8601String().substring(0, 10)}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
  }

  Future<int> importBackup(Uint8List bytes) async {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'prompt-lab-backup' ||
        decoded['tables'] is! Map<String, dynamic>) {
      throw const FormatException('Файл не является резервной копией Prompt Lab AI.');
    }
    final tables = decoded['tables'] as Map<String, dynamic>;
    final db = await AppDatabase.instance.database;
    var count = 0;
    await db.transaction((txn) async {
      // Parent tables are restored before dependent rows.
      for (final table in _tables) {
        final rows = tables[table];
        if (rows == null) continue;
        if (rows is! List) throw FormatException('Некорректная таблица $table.');
        for (final raw in rows) {
          if (raw is! Map) continue;
          final row = Map<String, Object?>.from(raw);
          // Ignore malformed/unknown columns through SQLite's strict schema check.
          await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
          count++;
        }
      }
    });
    final rawPreferences = decoded['preferences'];
    if (rawPreferences is Map) {
      final preferences = await SharedPreferences.getInstance();
      for (final entry in rawPreferences.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is String) await preferences.setString(key, value);
        else if (value is bool) await preferences.setBool(key, value);
        else if (value is int) await preferences.setInt(key, value);
        else if (value is double) await preferences.setDouble(key, value);
        else if (value is List) await preferences.setStringList(key, value.map((item) => item.toString()).toList());
      }
    }
    return count;
  }

  Future<int> importSelectedFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['json'], withData: true,
    );
    if (result == null || result.files.single.bytes == null) return 0;
    return importBackup(result.files.single.bytes!);
  }
}
