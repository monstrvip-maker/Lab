import '../database/app_database.dart';
import '../models/prompt_record.dart';

class PromptRepository {
  PromptRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<PromptRecord>> getAll({String? search, bool favoritesOnly = false}) async {
    final db = await _database.database;
    final clauses = <String>[];
    final args = <Object?>[];

    if (favoritesOnly) clauses.add('is_favorite = 1');
    if (search != null && search.trim().isNotEmpty) {
      clauses.add('(title LIKE ? OR original_text LIKE ? OR category LIKE ?)');
      final pattern = '%${search.trim()}%';
      args.addAll([pattern, pattern, pattern]);
    }

    final rows = await db.query(
      'prompts',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'updated_at DESC',
    );
    return rows.map(PromptRecord.fromMap).toList();
  }

  Future<int> create({
    required String title,
    required String originalText,
    String category = 'Без категории',
    String? sourceUrl,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    return db.transaction((txn) async {
      final id = await txn.insert('prompts', {
        'title': title.trim().isEmpty ? 'Новый промт' : title.trim(),
        'original_text': originalText.trim(),
        'category': category,
        'source_url': sourceUrl,
        'is_favorite': 0,
        'created_at': now,
        'updated_at': now,
      });

      await txn.insert('prompt_versions', {
        'prompt_id': id,
        'version_number': 1,
        'content': originalText.trim(),
        'note': 'Оригинал',
        'created_at': now,
      });
      return id;
    });
  }

  Future<void> update(PromptRecord prompt) async {
    if (prompt.id == null) return;
    final db = await _database.database;
    await db.update(
      'prompts',
      {
        ...prompt.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [prompt.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _database.database;
    await db.delete('prompts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setFavorite(int id, bool value) async {
    final db = await _database.database;
    await db.update(
      'prompts',
      {'is_favorite': value ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
