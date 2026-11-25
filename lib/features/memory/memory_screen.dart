import 'package:flutter/material.dart';
import '../../data/repositories/memory_repository.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});
  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  final _repo = MemoryRepository();
  final _search = TextEditingController();
  late Future<List<MemoryItem>> _future;
  @override
  void initState() { super.initState(); _reload(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  void _reload() { _future = _repo.list(search: _search.text); }

  Future<void> _edit([MemoryItem? item]) async {
    final title = TextEditingController(text: item?.title ?? '');
    final content = TextEditingController(text: item?.content ?? '');
    final tags = TextEditingController(text: item?.tags ?? '');
    var category = item?.category ?? 'Факт';
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: Text(item == null ? 'Добавить в память' : 'Изменить память'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Короткое название')),
        const SizedBox(height: 8),
        TextField(controller: content, minLines: 3, maxLines: 7, decoration: const InputDecoration(labelText: 'Что нужно запомнить')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Тип знания'), items: const [
          DropdownMenuItem(value: 'Факт', child: Text('Факт')),
          DropdownMenuItem(value: 'Предпочтение', child: Text('Предпочтение')),
          DropdownMenuItem(value: 'Правило', child: Text('Правило')),
          DropdownMenuItem(value: 'Проект', child: Text('Проект')),
        ], onChanged: (v) => setDialog(() => category = v ?? 'Факт')),
        const SizedBox(height: 8),
        TextField(controller: tags, decoration: const InputDecoration(labelText: 'Теги через запятую')),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(ctx, title.text.trim().isNotEmpty && content.text.trim().isNotEmpty), child: const Text('Сохранить')),
      ],
    )));
    if (ok == true) {
      if (item == null) {
        await _repo.save(title: title.text, content: content.text, category: category, tags: tags.text);
      } else {
        await _repo.update(item, title: title.text, content: content.text, category: category, tags: tags.text);
      }
    }
    title.dispose(); content.dispose(); tags.dispose();
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Память AI')),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Запомнить')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _search, onChanged: (_) => setState(_reload), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Поиск по памяти'))),
      const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 12), child: Text('Здесь хранятся подтверждённые факты, предпочтения и правила. Память можно просматривать, исправлять и удалять.', textAlign: TextAlign.center)),
      Expanded(child: FutureBuilder<List<MemoryItem>>(future: _future, builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text('Ошибка памяти: ${snap.error}'));
        final items = snap.data ?? [];
        if (items.isEmpty) return const Center(child: Text('Память пока пуста. Добавь первое знание.'));
        return ListView.separated(padding: const EdgeInsets.fromLTRB(16, 0, 16, 90), itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, i) {
          final item = items[i];
          return Card(child: ListTile(
            leading: Icon(item.category == 'Предпочтение' ? Icons.tune : item.category == 'Правило' ? Icons.rule : Icons.psychology_outlined),
            title: Text(item.title),
            subtitle: Text('${item.content}\n${item.category} · ${item.tags}', maxLines: 4, overflow: TextOverflow.ellipsis),
            isThreeLine: true,
            onTap: () => _edit(item),
            trailing: IconButton(tooltip: 'Удалить из памяти', icon: const Icon(Icons.delete_outline), onPressed: () async { await _repo.delete(item.id); if (mounted) setState(_reload); }),
          ));
        });
      })),
    ]),
  );
}
