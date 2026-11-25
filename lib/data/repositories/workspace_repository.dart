import '../database/app_database.dart';

class WorkspaceProject {
  const WorkspaceProject({required this.id, required this.name, required this.description, required this.status, required this.createdAt});
  final int id;
  final String name;
  final String description;
  final String status;
  final DateTime createdAt;
}

class ProjectTask {
  const ProjectTask({required this.id, required this.projectId, required this.title, required this.details, required this.status, required this.priority});
  final int id;
  final int projectId;
  final String title;
  final String details;
  final String status;
  final int priority;
}

class KnowledgeNote {
  const KnowledgeNote({required this.id, required this.title, required this.content, required this.tags, this.projectId, required this.isPinned, required this.updatedAt});
  final int id;
  final String title;
  final String content;
  final String tags;
  final int? projectId;
  final bool isPinned;
  final DateTime updatedAt;
}

class WorkspaceRepository {
  final AppDatabase _database = AppDatabase.instance;

  Future<List<WorkspaceProject>> projects() async {
    final db = await _database.database;
    final rows = await db.query('projects', orderBy: 'updated_at DESC');
    return rows.map((r) => WorkspaceProject(
      id: r['id'] as int,
      name: r['name'] as String,
      description: r['description'] as String,
      status: r['status'] as String,
      createdAt: DateTime.parse(r['created_at'] as String),
    )).toList();
  }

  Future<int> addProject(String name, String description) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    return db.insert('projects', {'name': name.trim(), 'description': description.trim(), 'created_at': now, 'updated_at': now});
  }

  Future<void> deleteProject(int id) async {
    final db = await _database.database;
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ProjectTask>> tasks(int projectId) async {
    final db = await _database.database;
    final rows = await db.query('project_tasks', where: 'project_id = ?', whereArgs: [projectId], orderBy: 'priority ASC, created_at ASC');
    return rows.map((r) => ProjectTask(
      id: r['id'] as int, projectId: r['project_id'] as int, title: r['title'] as String,
      details: r['details'] as String, status: r['status'] as String, priority: r['priority'] as int,
    )).toList();
  }

  Future<void> addTask(int projectId, String title, String details) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('project_tasks', {'project_id': projectId, 'title': title.trim(), 'details': details.trim(), 'created_at': now, 'updated_at': now});
  }

  Future<void> updateTaskStatus(int id, String status) async {
    final db = await _database.database;
    await db.update('project_tasks', {'status': status, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTask(int id) async {
    final db = await _database.database;
    await db.delete('project_tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<KnowledgeNote>> notes({String search = ''}) async {
    final db = await _database.database;
    final q = search.trim();
    final rows = await db.query('knowledge_notes',
      where: q.isEmpty ? null : '(title LIKE ? OR content LIKE ? OR tags LIKE ?)',
      whereArgs: q.isEmpty ? null : ['%$q%', '%$q%', '%$q%'],
      orderBy: 'is_pinned DESC, updated_at DESC');
    return rows.map((r) => KnowledgeNote(
      id: r['id'] as int, title: r['title'] as String, content: r['content'] as String,
      tags: r['tags'] as String, projectId: r['project_id'] as int?,
      isPinned: (r['is_pinned'] as int) == 1, updatedAt: DateTime.parse(r['updated_at'] as String),
    )).toList();
  }

  Future<void> saveNote({int? id, required String title, required String content, required String tags, int? projectId}) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    final values = {'title': title.trim(), 'content': content.trim(), 'tags': tags.trim(), 'project_id': projectId, 'updated_at': now};
    if (id == null) {
      await db.insert('knowledge_notes', {...values, 'created_at': now});
    } else {
      await db.update('knowledge_notes', values, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> togglePinned(KnowledgeNote note) async {
    final db = await _database.database;
    await db.update('knowledge_notes', {'is_pinned': note.isPinned ? 0 : 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [note.id]);
  }

  Future<void> deleteNote(int id) async {
    final db = await _database.database;
    await db.delete('knowledge_notes', where: 'id = ?', whereArgs: [id]);
  }
}
