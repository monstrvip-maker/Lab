import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../data/repositories/workspace_repository.dart';
import '../../data/repositories/knowledge_index_repository.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key});
  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  final _repo = WorkspaceRepository();
  final _index = KnowledgeIndexRepository();
  Future<List<KnowledgeSearchHit>>? _indexFuture;
  final _search = TextEditingController();
  late Future<List<KnowledgeNote>> _future;

  @override
  void initState() { super.initState(); _reload(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  void _reload() { _future = _repo.notes(search: _search.text); _indexFuture = _search.text.trim().length < 3 ? null : _index.search(_search.text); }

  Future<void> _importDocument() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'md'], withData: true);
    if (result == null || result.files.single.bytes == null) return;
    try {
      final file = result.files.single;
      final content = utf8.decode(file.bytes!, allowMalformed: true);
      await _index.importText(title: file.name, sourceName: file.name, content: content);
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Документ разбит на фрагменты и добавлен в локальный индекс')));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось импортировать документ: $error')));
    }
  }

  Future<void> _edit([KnowledgeNote? note]) async {
    final title = TextEditingController(text: note?.title ?? '');
    final content = TextEditingController(text: note?.content ?? '');
    final tags = TextEditingController(text: note?.tags ?? '');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(note == null ? 'Новая заметка' : 'Изменить заметку'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Название')),
        const SizedBox(height: 8),
        TextField(controller: content, minLines: 5, maxLines: 10, decoration: const InputDecoration(labelText: 'Содержание')),
        const SizedBox(height: 8),
        TextField(controller: tags, decoration: const InputDecoration(labelText: 'Теги через запятую')),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(ctx, title.text.trim().isNotEmpty && content.text.trim().isNotEmpty), child: const Text('Сохранить')),
      ],
    ));
    if (ok == true) await _repo.saveNote(id: note?.id, title: title.text, content: content.text, tags: tags.text);
    title.dispose(); content.dispose(); tags.dispose();
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('База знаний'), actions: [IconButton(tooltip: 'Импорт TXT/Markdown', onPressed: _importDocument, icon: const Icon(Icons.file_upload_outlined))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Заметка')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _search, onChanged: (_) => setState(_reload), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Поиск по заметкам и тегам'))),
      if (_indexFuture != null) FutureBuilder<List<KnowledgeSearchHit>>(future: _indexFuture, builder: (context, snap) {
        final hits = snap.data ?? [];
        if (hits.isEmpty) return const SizedBox.shrink();
        return SizedBox(height: 210, child: ListView.builder(itemCount: hits.length, itemBuilder: (context, i) {
          final hit = hits[i];
          return ListTile(dense: true, leading: const Icon(Icons.article_outlined), title: Text(hit.title), subtitle: Text(hit.content, maxLines: 2, overflow: TextOverflow.ellipsis), onTap: () => showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: Text(hit.title), content: SingleChildScrollView(child: SelectableText(hit.content)), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))])));
        }));
      }),
      Expanded(child: FutureBuilder<List<KnowledgeNote>>(future: _future, builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text('Ошибка: ${snap.error}'));
        final notes = snap.data ?? [];
        if (notes.isEmpty) return const Center(child: Text('Пока нет заметок. Сохраняйте сюда решения, инструкции и полезные знания.'));
        return ListView.separated(padding: const EdgeInsets.fromLTRB(16, 0, 16, 90), itemCount: notes.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, i) {
          final n = notes[i];
          return Card(child: ListTile(
            leading: Icon(n.isPinned ? Icons.push_pin : Icons.lightbulb_outline),
            title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${n.content}\n${n.tags}', maxLines: 3, overflow: TextOverflow.ellipsis),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(onSelected: (v) async {
              if (v == 'pin') await _repo.togglePinned(n);
              if (v == 'edit') { await _edit(n); return; }
              if (v == 'delete') await _repo.deleteNote(n.id);
              if (mounted) setState(_reload);
            }, itemBuilder: (_) => [
              PopupMenuItem(value: 'pin', child: Text(n.isPinned ? 'Открепить' : 'Закрепить')),
              const PopupMenuItem(value: 'edit', child: Text('Изменить')),
              const PopupMenuItem(value: 'delete', child: Text('Удалить')),
            ]),
            onTap: () => showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: Text(n.title), content: SingleChildScrollView(child: SelectableText(n.content)), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))])),
          ));
        });
      })),
    ]),
  );
}
