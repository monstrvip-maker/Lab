import 'dart:convert';

import '../database/app_database.dart';

class LearningQueueItem {
  const LearningQueueItem({
    required this.id,
    required this.taskType,
    required this.payload,
    required this.status,
    required this.attempts,
    required this.lastError,
    required this.createdAt,
  });

  final int id;
  final String taskType;
  final Map<String, dynamic> payload;
  final String status;
  final int attempts;
  final String lastError;
  final DateTime createdAt;

  factory LearningQueueItem.fromMap(Map<String, Object?> row) {
    final decoded = jsonDecode(row['payload'] as String);
    return LearningQueueItem(
      id: row['id'] as int,
      taskType: row['task_type'] as String,
      payload: decoded is Map<String, dynamic> ? decoded : <String, dynamic>{},
      status: row['status'] as String,
      attempts: row['attempts'] as int,
      lastError: row['last_error'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

/// Durable queue primitives. A worker (WorkManager) can claim and resume items
/// later; this repository itself never starts background work.
class LearningQueueRepository {
  Future<int> enqueue(String taskType, Map<String, dynamic> payload) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    return db.insert('learning_queue', {
      'task_type': taskType,
      'payload': jsonEncode(payload),
      'status': 'pending',
      'attempts': 0,
      'last_error': '',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<LearningQueueItem>> list({int limit = 100}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('learning_queue', orderBy: 'created_at DESC', limit: limit);
    return rows.map(LearningQueueItem.fromMap).toList();
  }

  Future<LearningQueueItem?> claimNext({int maxAttempts = 5}) async {
    final db = await AppDatabase.instance.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'learning_queue',
        where: "status IN ('pending', 'retry') AND attempts < ?",
        whereArgs: [maxAttempts],
        orderBy: 'created_at ASC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      final id = row['id'] as int;
      final changed = await txn.update(
        'learning_queue',
        {'status': 'running', 'updated_at': DateTime.now().toUtc().toIso8601String()},
        where: "id = ? AND status IN ('pending', 'retry')",
        whereArgs: [id],
      );
      if (changed != 1) return null;
      final refreshed = Map<String, Object?>.from(row)
        ..['status'] = 'running';
      return LearningQueueItem.fromMap(refreshed);
    });
  }

  Future<void> complete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.update('learning_queue', {
      'status': 'completed',
      'last_error': '',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, where: "id = ? AND status = 'running'", whereArgs: [id]);
  }

  Future<void> fail(int id, Object error, {int maxAttempts = 5}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('learning_queue', columns: ['attempts'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final attempts = (rows.first['attempts'] as int) + 1;
    await db.update('learning_queue', {
      'attempts': attempts,
      'status': attempts >= maxAttempts ? 'failed' : 'retry',
      'last_error': error.toString().substring(0, error.toString().length.clamp(0, 1000)),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> retryFailed(int id) async {
    final db = await AppDatabase.instance.database;
    await db.update('learning_queue', {
      'status': 'retry', 'attempts': 0, 'last_error': '',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, where: "id = ? AND status = 'failed'", whereArgs: [id]);
  }

  Future<void> clearCompleted() async {
    final db = await AppDatabase.instance.database;
    await db.delete('learning_queue', where: "status = 'completed'");
  }
}
