import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

/// Portable JSON backup. Only app-owned tables are exported/imported.
class BackupRepository {
  static const _tables = <String>[
    'prompts', 'prompt_versions', 'projects', 'project_tasks',
    'knowledge_notes', 'memory_items', 'memory_feedback',
    'task_checkpoints', 'prompt_tests', 'knowledge_sources', 'agent_runs',
    'learning_state', 'learning_history', 'task_dependencies', 'knowledge_documents', 'knowledge_chunks', 'learning_queue',
  ];

  Future<Uint8List> exportBytes() async {
    final db = await AppDatabase.instance.database;
    final payload = <String, Object?>{
      'format': 'prompt-lab-backup',
      'schema': 6,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': <String, Object?>{},
    };
    final data = <String, Object?>{};
    for (final table in _tables) {
      data[table] = await db.query(table);
    }
    payload['tables'] = data;
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
