import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/prompt_record.dart';
import '../../data/repositories/prompt_repository.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _repository = PromptRepository();
  late Future<List<PromptRecord>> _future;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() { _future = _repository.getAll(favoritesOnly: true); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Избранное')),
    body: FutureBuilder<List<PromptRecord>>(future: _future, builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: Text('Ошибка загрузки: ${snap.error}'));
      final prompts = snap.data ?? [];
      if (prompts.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.star_border_rounded, size: 56), SizedBox(height: 12),
        Text('Пока здесь пусто', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        SizedBox(height: 6), Text('Отмечай промты звёздочкой в библиотеке — они появятся здесь.', textAlign: TextAlign.center),
      ])));
      return ListView.separated(padding: const EdgeInsets.all(16), itemCount: prompts.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, i) {
        final p = prompts[i];
        return Card(child: ListTile(
          title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(p.originalText, maxLines: 3, overflow: TextOverflow.ellipsis),
          onTap: () => showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: Text(p.title), content: SingleChildScrollView(child: SelectableText(p.originalText)), actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
            FilledButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: p.originalText)); Navigator.pop(ctx); }, icon: const Icon(Icons.copy), label: const Text('Копировать')),
          ])),
          trailing: IconButton(tooltip: 'Убрать из избранного', icon: const Icon(Icons.star), onPressed: () async {
            await _repository.setFavorite(p.id!, false);
            if (mounted) setState(_reload);
          }),
        ));
      });
    }),
  );
}
