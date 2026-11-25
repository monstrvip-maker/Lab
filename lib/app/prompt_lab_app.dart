import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../ai/runtime/local_ai_runtime.dart';
import '../features/navigation/main_navigation.dart';

class PromptLabApp extends StatefulWidget {
  const PromptLabApp({super.key});

  @override
  State<PromptLabApp> createState() => _PromptLabAppState();
}

class _PromptLabAppState extends State<PromptLabApp> {
  @override
  void initState() {
    super.initState();
    LocalAiRuntime.instance.initialize();
  }

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
