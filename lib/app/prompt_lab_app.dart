import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../ai/runtime/local_ai_runtime.dart';
import '../features/navigation/main_navigation.dart';
import '../data/repositories/backup_repository.dart';

class PromptLabApp extends StatefulWidget {
  const PromptLabApp({super.key});

  @override
  State<PromptLabApp> createState() => _PromptLabAppState();
}

class _PromptLabAppState extends State<PromptLabApp> with WidgetsBindingObserver {
  final _backup = BackupRepository();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LocalAiRuntime.instance.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _backup.autoBackup().catchError((_) => null);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
