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
      version: 5,
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
    await _createWorkspaceSchema(db);
    await _createMemorySchema(db);
    await _createAdvancedSchema(db);
    await _createLearningSchema(db);
  }


  Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createWorkspaceSchema(db);
    }
    if (oldVersion < 3) {
      await _createMemorySchema(db);
    }
    if (oldVersion < 4) {
      await _createAdvancedSchema(db);
    }
  }

  Future<void> _createAdvancedSchema(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS task_checkpoints (
      id INTEGER PRIMARY KEY AUTOINCREMENT, task_id INTEGER NOT NULL,
      title TEXT NOT NULL, is_done INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL, completed_at TEXT,
      FOREIGN KEY(task_id) REFERENCES project_tasks(id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS prompt_tests (
      id INTEGER PRIMARY KEY AUTOINCREMENT, prompt_id INTEGER,
      input TEXT NOT NULL, expected TEXT NOT NULL DEFAULT '', actual TEXT NOT NULL DEFAULT '',
      passed INTEGER NOT NULL DEFAULT 0, notes TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      FOREIGN KEY(prompt_id) REFERENCES prompts(id) ON DELETE SET NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS knowledge_sources (
      id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
      source_type TEXT NOT NULL, source_ref TEXT NOT NULL DEFAULT '',
      content TEXT NOT NULL, checksum TEXT NOT NULL DEFAULT '',
      imported_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS agent_runs (
      id INTEGER PRIMARY KEY AUTOINCREMENT, task TEXT NOT NULL,
      plan TEXT NOT NULL DEFAULT '', result TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL DEFAULT 'completed', created_at TEXT NOT NULL
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_checkpoints_task ON task_checkpoints(task_id, is_done)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_prompt_tests_prompt ON prompt_tests(prompt_id, created_at DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_knowledge_sources_date ON knowledge_sources(imported_at DESC)');
  }


  Future<void> _createLearningSchema(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS learning_state (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      learned_count INTEGER NOT NULL DEFAULT 0,
      saved_prompt_count INTEGER NOT NULL DEFAULT 0,
      cycle_count INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL
    )''');
    await db.execute('''INSERT OR IGNORE INTO learning_state
      (id, learned_count, saved_prompt_count, cycle_count, updated_at)
      VALUES (1, 0, 0, 0, '')''');
    await db.execute('''CREATE TABLE IF NOT EXISTS learning_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      topic TEXT NOT NULL,
      title TEXT NOT NULL,
      source_url TEXT NOT NULL,
      provider TEXT NOT NULL DEFAULT '',
      summary TEXT NOT NULL DEFAULT '',
      prompt_id INTEGER,
      created_at TEXT NOT NULL,
      FOREIGN KEY(prompt_id) REFERENCES prompts(id) ON DELETE SET NULL
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_learning_history_created ON learning_history(created_at DESC)');
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


  Future<void> _createMemorySchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS memory_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'Факт',
        tags TEXT NOT NULL DEFAULT '',
        source TEXT NOT NULL DEFAULT 'Пользователь',
        confidence REAL NOT NULL DEFAULT 1.0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS memory_feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task TEXT NOT NULL,
        response TEXT NOT NULL,
        rating INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_memory_active ON memory_items(is_active, updated_at DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_memory_feedback_created ON memory_feedback(created_at DESC)');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
