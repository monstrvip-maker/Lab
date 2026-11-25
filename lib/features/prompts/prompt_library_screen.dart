import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/prompt_record.dart';
import '../../data/repositories/prompt_repository.dart';
import '../../data/repositories/advanced_repository.dart';
import '../../data/repositories/workspace_repository.dart';
import 'prompt_test_screen.dart';

class PromptLibraryScreen extends StatefulWidget {
  const PromptLibraryScreen({super.key});

  @override
  State<PromptLibraryScreen> createState() => _PromptLibraryScreenState();
}

class _PromptLibraryScreenState extends State<PromptLibraryScreen> {
  final PromptRepository _repository = PromptRepository();
  final AdvancedRepository _advanced = AdvancedRepository();
  final WorkspaceRepository _projects = WorkspaceRepository();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<PromptRecord>> _promptsFuture;
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    _promptsFuture = _repository.getAll(
      search: _searchController.text,
      favoritesOnly: _favoritesOnly,
    );
  }

  Future<void> _addPrompt() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Добавить промт'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Оригинальный текст промта',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (bodyController.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result == true && bodyController.text.trim().isNotEmpty) {
      await _repository.create(
        title: titleController.text,
        originalText: bodyController.text,
      );
      if (mounted) setState(_reload);
    }
    titleController.dispose();
    bodyController.dispose();
  }



  Future<void> _assignProject(PromptRecord prompt) async {
    final projects = await _projects.projects();
    if (!mounted) return;
    final selected = await showDialog<int?>(context: context, builder: (ctx) => SimpleDialog(
      title: const Text('Связать промт с проектом'),
      children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, -1), child: const Text('Не связывать')),
        for (final project in projects)
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, project.id), child: Text(project.name)),
      ],
    ));
    if (selected == null) return;
    await _repository.assignProject(prompt.id!, selected == -1 ? null : selected);
    if (mounted) {
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Связь с проектом обновлена')));
    }
  }

  Future<void> _showVersions(PromptRecord prompt) async {
    final rows = await _advanced.promptVersions(prompt.id!);
    if (!mounted) return;
    final latest = rows.length > 1 ? rows[rows.length - 2] : (rows.isEmpty ? null : rows.last);
    final current = rows.isEmpty ? null : rows.last;
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('История версий и сравнение'),
      content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
        children: [
          Text('Сохранено версий: ${rows.length}'),
          for (final row in rows) ListTile(
            dense: true, title: Text('Версия ${row['version_number']}'),
            subtitle: Text('${row['note'] ?? ''} · ${row['created_at']}'),
          ),
          if (latest != null && current != null) ...[
            const Divider(),
            const Text('Сравнение двух последних версий', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(_simpleDiff(latest['content'] as String, current['content'] as String)),
          ],
        ],
      ))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))],
    ));
  }

  String _simpleDiff(String before, String after) {
    if (before == after) return 'Изменений нет.';
    final oldLines = before.split('\n');
    final newLines = after.split('\n');
    final output = <String>[];
    for (final line in oldLines) {
      if (!newLines.contains(line)) output.add('− $line');
    }
    for (final line in newLines) {
      if (!oldLines.contains(line)) output.add('+ $line');
    }
    return output.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Библиотека промтов'),
        actions: [
          IconButton(
            tooltip: _favoritesOnly ? 'Показать все' : 'Только избранное',
            onPressed: () => setState(() {
              _favoritesOnly = !_favoritesOnly;
              _reload();
            }),
            icon: Icon(_favoritesOnly ? Icons.star : Icons.star_border),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPrompt,
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(_reload),
              decoration: const InputDecoration(
                hintText: 'Поиск по названию, тексту и категории',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<PromptRecord>>(
              future: _promptsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка базы данных: ${snapshot.error}'));
                }
                final prompts = snapshot.data ?? const <PromptRecord>[];
                if (prompts.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'Пока нет сохранённых промтов. Добавь первый оригинал — он будет сохранён локально.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: prompts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final prompt = prompts[index];
                    return Card(
                      child: ListTile(
                        title: Text(prompt.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          prompt.improvedText ?? prompt.originalText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: prompt.isFavorite ? 'Убрать из избранного' : 'В избранное',
                          icon: Icon(prompt.isFavorite ? Icons.star : Icons.star_border),
                          onPressed: () async {
                            await _repository.setFavorite(prompt.id!, !prompt.isFavorite);
                            if (mounted) setState(_reload);
                          },
                        ),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(prompt.title),
                            content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Исходная задача', style: TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                SelectableText(prompt.originalText),
                                if (prompt.improvedText != null && prompt.improvedText!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  const Text('Версия Qwen', style: TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  SelectableText(prompt.improvedText!),
                                ],
                              ],
                            ),
                          ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Закрыть'),
                              ),
                              if (prompt.improvedText != null && prompt.improvedText!.trim().isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: prompt.improvedText!));
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Копировать Qwen'),
                                ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PromptTestScreen(prompt: prompt)));
                                },
                                child: const Text('Тестировать'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _assignProject(prompt);
                                },
                                child: const Text('Проект'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showVersions(prompt);
                                },
                                child: const Text('Версии'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _repository.delete(prompt.id!);
                                  if (mounted) setState(_reload);
                                },
                                child: const Text('Удалить'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
