import 'package:flutter/material.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Избранное')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_border_rounded, size: 56),
                SizedBox(height: 12),
                Text('Пока здесь пусто', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Text('Сохраняй сюда важные промты, проекты и знания.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
              ],
            ),
          ),
        ),
      );
}
