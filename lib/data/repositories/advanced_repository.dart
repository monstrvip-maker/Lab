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
