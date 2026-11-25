import '../database/app_database.dart';

class MemoryItem {
  const MemoryItem({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.tags,
    required this.source,
    required this.confidence,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String content;
  final String category;
  final String tags;
  final String source;
  final double confidence;
  final DateTime createdAt;

  factory MemoryItem.fromMap(Map<String, Object?> row) => MemoryItem(
    id: row['id'] as int,
    title: row['title'] as String,
    content: row['content'] as String,
    category: row['category'] as String,
    tags: row['tags'] as String,
    source: row['source'] as String,
    confidence: (row['confidence'] as num).toDouble(),
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

class MemoryRepository {
  MemoryRepository({AppDatabase? database}) : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  Future<List<MemoryItem>> list({String search = ''}) async {
    final db = await _database.database;
    final q = search.trim();
    final rows = await db.query(
      'memory_items',
      where: q.isEmpty
          ? 'is_active = 1'
          : "is_active = 1 AND (title LIKE ? OR content LIKE ? OR tags LIKE ?)",
      whereArgs: q.isEmpty ? null : ['%$q%', '%$q%', '%$q%'],
      orderBy: 'updated_at DESC',
      limit: 200,
    );
    return rows.map(MemoryItem.fromMap).toList();
  }

  Future<List<MemoryItem>> relevant(String query, {int limit = 5}) async {
    final all = await list();
    final terms = query.toLowerCase().split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.length >= 3).toSet();
    if (terms.isEmpty) return all.where((m) => m.category == 'Предпочтение').take(limit).toList();
    final scored = all.map((m) {
      final haystack = '${m.title} ${m.content} ${m.tags}'.toLowerCase();
      final score = terms.where(haystack.contains).length;
      return (item: m, score: score);
    }).where((x) => x.score > 0 || x.item.category == 'Предпочтение').toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((x) => x.item).toList();
  }

  Future<int> save({
    required String title,
    required String content,
    String category = 'Факт',
    String tags = '',
    String source = 'Пользователь',
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    return db.insert('memory_items', {
      'title': title.trim(),
      'content': content.trim(),
      'category': category,
      'tags': tags,
      'source': source,
      'confidence': 1.0,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> update(MemoryItem item, {required String title, required String content, required String category, required String tags}) async {
    final db = await _database.database;
    await db.update('memory_items', {
      'title': title.trim(), 'content': content.trim(), 'category': category,
      'tags': tags, 'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> delete(int id) async {
    final db = await _database.database;
    await db.delete('memory_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> rate({required String task, required String response, required int rating, String note = ''}) async {
    final db = await _database.database;
    await db.insert('memory_feedback', {
      'task': task, 'response': response, 'rating': rating, 'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
