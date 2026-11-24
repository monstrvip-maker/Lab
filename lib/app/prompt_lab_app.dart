import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/navigation/main_navigation.dart';

class PromptLabApp extends StatelessWidget {
  const PromptLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prompt Lab AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const MainNavigation(),
    );
  }
}
