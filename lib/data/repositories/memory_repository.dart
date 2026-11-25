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

  List<String> _terms(String text) => text.toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((word) => word.length >= 3)
      .toList();

  Future<List<MemoryItem>> relevant(String query, {int limit = 5}) async {
    final all = await list();
    final terms = _terms(query).toSet();
    if (terms.isEmpty) return all.where((m) => m.category == 'Предпочтение').take(limit).toList();

    final documentFrequency = <String, int>{};
    for (final item in all) {
      final words = _terms('${item.title} ${item.content} ${item.tags}').toSet();
      for (final word in words) {
        documentFrequency[word] = (documentFrequency[word] ?? 0) + 1;
      }
    }
    final scored = all.map((item) {
      final title = _terms(item.title);
      final body = _terms(item.content);
      final tags = _terms(item.tags);
      var score = 0.0;
      for (final term in terms) {
        final tfTitle = title.where((word) => word == term).length;
        final tfTags = tags.where((word) => word == term).length;
        final tfBody = body.where((word) => word == term).length;
        final idf = 1 + (all.length / (1 + (documentFrequency[term] ?? 0)));
        score += (tfTitle * 3.0 + tfTags * 2.2 + tfBody) * idf;
      }
      if (item.title.toLowerCase().contains(query.toLowerCase())) score += 5;
      if (item.category == 'Предпочтение') score += 0.7;
      score *= item.confidence.clamp(0.1, 1.0).toDouble();
      return (item: item, score: score);
    }).where((entry) => entry.score > 0)
      .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((entry) => entry.item).toList();
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

  Future<String> feedbackContext({int limit = 4}) async {
    final db = await _database.database;
    final rows = await db.query('memory_feedback', orderBy: 'created_at DESC', limit: limit);
    if (rows.isEmpty) return '';
    return rows.map((row) {
      final rating = (row['rating'] as int) > 0 ? 'ПОЛЕЗНО' : 'НЕПОЛЕЗНО';
      final task = (row['task'] as String);
      final note = (row['note'] as String?) ?? '';
      return '- $rating: запрос «${task.length > 100 ? task.substring(0, 100) : task}»${note.isEmpty ? '' : '; комментарий: $note'}';
    }).join('\\n');
  }

  Future<void> rate({required String task, required String response, required int rating, String note = ''}) async {
    final db = await _database.database;
    await db.insert('memory_feedback', {
      'task': task, 'response': response, 'rating': rating, 'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
