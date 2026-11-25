import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async {
    final current = _database;
    if (current != null) return current;

    final dbPath = path.join(await getDatabasesPath(), 'prompt_lab_ai.db');
    final opened = await openDatabase(
      dbPath,
      version: 2,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    _database = opened;
    return opened;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE prompts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        original_text TEXT NOT NULL,
        improved_text TEXT,
        category TEXT NOT NULL DEFAULT 'Без категории',
        source_url TEXT,
        analysis_json TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE prompt_versions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prompt_id INTEGER NOT NULL,
        version_number INTEGER NOT NULL,
        content TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(prompt_id) REFERENCES prompts(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_prompts_updated_at ON prompts(updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_prompts_category ON prompts(category)',
    );
  }


  Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createWorkspaceSchema(db);
    }
  }

  Future<void> _createWorkspaceSchema(Database db) async {
    await db.execute('''
      CREATE TABLE projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'Активен',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE project_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        details TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'Запланировано',
        priority INTEGER NOT NULL DEFAULT 2,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE knowledge_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        tags TEXT NOT NULL DEFAULT '',
        project_id INTEGER,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_project_tasks_project ON project_tasks(project_id, status)');
    await db.execute('CREATE INDEX idx_knowledge_updated ON knowledge_notes(updated_at DESC)');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
