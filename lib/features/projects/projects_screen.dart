import 'package:flutter/material.dart';
import '../../data/repositories/workspace_repository.dart';
import '../../data/repositories/advanced_repository.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _repo = WorkspaceRepository();
  late Future<List<WorkspaceProject>> _future;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() { _future = _repo.projects(); }

  Future<void> _addProject() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Новый проект'),
      content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Название проекта')),
        const SizedBox(height: 8),
        TextField(controller: description, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Описание и цель')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(ctx, name.text.trim().isNotEmpty), child: const Text('Создать')),
      ],
    ));
    if (ok == true) await _repo.addProject(name.text, description.text);
    name.dispose(); description.dispose();
    if (mounted) setState(_reload);
  }

  Future<void> _openProject(WorkspaceProject project) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ProjectDetailScreen(project: project, repository: _repo)));
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Проекты')),
    floatingActionButton: FloatingActionButton.extended(onPressed: _addProject, icon: const Icon(Icons.create_new_folder_outlined), label: const Text('Новый проект')),
    body: FutureBuilder<List<WorkspaceProject>>(future: _future, builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: Text('Ошибка базы данных: ${snap.error}'));
      final projects = snap.data ?? [];
      if (projects.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.folder_open, size: 54), SizedBox(height: 12), Text('Создай первый проект', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        SizedBox(height: 6), Text('В каждом проекте можно хранить описание и задачи со статусами.', textAlign: TextAlign.center),
      ])));
      return ListView.separated(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), itemCount: projects.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, i) {
        final p = projects[i];
        return Card(child: ListTile(leading: const Icon(Icons.folder_copy_outlined), title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(p.description.isEmpty ? p.status : p.description, maxLines: 2, overflow: TextOverflow.ellipsis), trailing: const Icon(Icons.chevron_right), onTap: () => _openProject(p)));
      });
    }),
  );
}

class _ProjectDetailScreen extends StatefulWidget {
  const _ProjectDetailScreen({required this.project, required this.repository});
  final WorkspaceProject project;
  final WorkspaceRepository repository;
  @override
  State<_ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<_ProjectDetailScreen> {
  final _advanced = AdvancedRepository();
  late Future<List<ProjectTask>> _future;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() { _future = widget.repository.tasks(widget.project.id); }

  Future<void> _addTask() async {
    final title = TextEditingController();
    final details = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Новая задача'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Название')),
        const SizedBox(height: 8),
        TextField(controller: details, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Описание')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(ctx, title.text.trim().isNotEmpty), child: const Text('Добавить'))],
    ));
    if (ok == true) await widget.repository.addTask(widget.project.id, title.text, details.text);
    title.dispose(); details.dispose();
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.project.name), actions: [
      IconButton(tooltip: 'Удалить проект', icon: const Icon(Icons.delete_outline), onPressed: () async {
        final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Удалить проект?'), content: const Text('Все задачи этого проекта будут удалены.'), actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ]));
        if (yes == true && context.mounted) { await widget.repository.deleteProject(widget.project.id); if (context.mounted) Navigator.pop(context); }
      }),
    ]),
    floatingActionButton: FloatingActionButton.extended(onPressed: _addTask, icon: const Icon(Icons.add_task), label: const Text('Добавить задачу')),
    body: Column(children: [
      if (widget.project.description.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text(widget.project.description))),
      Expanded(child: FutureBuilder<List<ProjectTask>>(future: _future, builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text('Ошибка: ${snap.error}'));
        final tasks = snap.data ?? [];
        if (tasks.isEmpty) return const Center(child: Text('Добавь первую задачу проекта'));
        return ListView.separated(padding: const EdgeInsets.fromLTRB(16, 0, 16, 90), itemCount: tasks.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, i) {
          final t = tasks[i];
          return Card(child: ExpansionTile(
            leading: Icon(t.status == 'Готово' ? Icons.check_circle : Icons.radio_button_unchecked),
            title: Text(t.title),
            subtitle: Text(t.details.isEmpty ? t.status : '${t.status} · ${t.details}', maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: PopupMenuButton<String>(onSelected: (v) async {
              if (v == 'delete') { await widget.repository.deleteTask(t.id); }
              else { await widget.repository.updateTaskStatus(t.id, v); }
              if (mounted) setState(_reload);
            }, itemBuilder: (_) => const [
              PopupMenuItem(value: 'Запланировано', child: Text('Запланировано')),
              PopupMenuItem(value: 'В работе', child: Text('В работе')),
              PopupMenuItem(value: 'Готово', child: Text('Готово')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'delete', child: Text('Удалить')),
            ]),
            children: [
              FutureBuilder<List<TaskCheckpoint>>(
                future: _advanced.checkpoints(t.id),
                builder: (context, checkpointSnap) {
                  final checkpoints = checkpointSnap.data ?? [];
                  return Column(children: [
                    if (checkpointSnap.connectionState == ConnectionState.waiting)
                      const LinearProgressIndicator(),
                    for (final checkpoint in checkpoints)
                      CheckboxListTile(
                        dense: true, value: checkpoint.done, title: Text(checkpoint.title),
                        onChanged: (value) async {
                          await _advanced.setCheckpoint(checkpoint.id, value ?? false);
                          if (mounted) setState(_reload);
                        },
                      ),
                    TextButton.icon(
                      onPressed: () async {
                        final controller = TextEditingController();
                        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                          title: const Text('Контрольная точка'),
                          content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Например: проверить подключение')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim().isNotEmpty), child: const Text('Добавить')),
                          ],
                        ));
                        if (ok == true) await _advanced.addCheckpoint(t.id, controller.text);
                        controller.dispose();
                        if (mounted) setState(_reload);
                      },
                      icon: const Icon(Icons.add_task), label: const Text('Добавить контрольную точку'),
                    ),
                  ]);
                },
              ),
            ],
          ));
        });
      })),
    ]),
  );
}
