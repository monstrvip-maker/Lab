import 'package:flutter/material.dart';

import '../../data/models/prompt_record.dart';
import '../../data/repositories/prompt_repository.dart';

class PromptLibraryScreen extends StatefulWidget {
  const PromptLibraryScreen({super.key});

  @override
  State<PromptLibraryScreen> createState() => _PromptLibraryScreenState();
}

class _PromptLibraryScreenState extends State<PromptLibraryScreen> {
  final PromptRepository _repository = PromptRepository();
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
                          prompt.originalText,
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
                            content: SingleChildScrollView(child: SelectableText(prompt.originalText)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Закрыть'),
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
