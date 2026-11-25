import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

class TaskCheckpoint {
  const TaskCheckpoint({required this.id, required this.taskId, required this.title, required this.done});
  final int id;
  final int taskId;
  final String title;
  final bool done;
}

class AdvancedRepository {
  Future<int> addCheckpoint(int taskId, String title) async {
    final db = await AppDatabase.instance.database;
    return db.insert('task_checkpoints', {
      'task_id': taskId, 'title': title.trim(), 'is_done': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<TaskCheckpoint>> checkpoints(int taskId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('task_checkpoints', where: 'task_id = ?', whereArgs: [taskId], orderBy: 'id ASC');
    return rows.map((r) => TaskCheckpoint(
      id: r['id'] as int, taskId: r['task_id'] as int,
      title: r['title'] as String, done: (r['is_done'] as int) == 1,
    )).toList();
  }

  Future<void> setCheckpoint(int id, bool done) async {
    final db = await AppDatabase.instance.database;
    await db.update('task_checkpoints', {
      'is_done': done ? 1 : 0,
      'completed_at': done ? DateTime.now().toIso8601String() : null,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCheckpoint(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('task_checkpoints', where: 'id = ?', whereArgs: [id]);
  }


  Future<void> addDependency(int taskId, int dependsOnTaskId) async {
    if (taskId == dependsOnTaskId) throw ArgumentError('Задача не может зависеть от самой себя.');
    final db = await AppDatabase.instance.database;
    final cycle = await db.rawQuery('''
      WITH RECURSIVE chain(id) AS (
        SELECT depends_on_task_id FROM task_dependencies WHERE task_id = ?
        UNION
        SELECT d.depends_on_task_id FROM task_dependencies d JOIN chain c ON d.task_id = c.id
      )
      SELECT 1 FROM chain WHERE id = ? LIMIT 1
    ''', [dependsOnTaskId, taskId]);
    if (cycle.isNotEmpty) throw StateError('Эта зависимость создаст цикл.');
    await db.insert('task_dependencies', {
      'task_id': taskId, 'depends_on_task_id': dependsOnTaskId,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, Object?>>> dependencies(int taskId) async {
    final db = await AppDatabase.instance.database;
    return db.rawQuery('''
      SELECT t.id, t.title, t.status FROM task_dependencies d
      JOIN project_tasks t ON t.id = d.depends_on_task_id
      WHERE d.task_id = ? ORDER BY t.priority, t.created_at
    ''', [taskId]);
  }

  Future<void> removeDependency(int taskId, int dependsOnTaskId) async {
    final db = await AppDatabase.instance.database;
    await db.delete('task_dependencies', where: 'task_id = ? AND depends_on_task_id = ?', whereArgs: [taskId, dependsOnTaskId]);
  }

  Future<bool> canCompleteTask(int taskId) async {
    final db = await AppDatabase.instance.database;
    final blocked = await db.rawQuery('''
      SELECT COUNT(*) AS count FROM task_dependencies d
      JOIN project_tasks t ON t.id = d.depends_on_task_id
      WHERE d.task_id = ? AND t.status != 'Готово'
    ''', [taskId]);
    return (blocked.first['count'] as int? ?? 0) == 0;
  }

  Future<List<Map<String, Object?>>> promptVersions(int promptId) async {
    final db = await AppDatabase.instance.database;
    return db.query('prompt_versions', where: 'prompt_id = ?', whereArgs: [promptId], orderBy: 'version_number ASC');
  }

  Future<List<Map<String, Object?>>> promptTestHistory(int promptId) async {
    final db = await AppDatabase.instance.database;
    return db.query('prompt_tests', where: 'prompt_id = ?', whereArgs: [promptId], orderBy: 'created_at DESC');
  }

  Future<void> savePromptTest({int? promptId, required String input, required String expected, required String actual, required bool passed, String notes = ''}) async {
    final db = await AppDatabase.instance.database;
    await db.insert('prompt_tests', {
      'prompt_id': promptId, 'input': input, 'expected': expected,
      'actual': actual, 'passed': passed ? 1 : 0, 'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> saveAgentRun({required String task, required String result, String plan = '', String status = 'completed'}) async {
    final db = await AppDatabase.instance.database;
    await db.insert('agent_runs', {
      'task': task, 'plan': plan, 'result': result, 'status': status,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
