import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../ai/runtime/local_ai_runtime.dart';
import '../../data/database/app_database.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});
  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final _runtime = LocalAiRuntime.instance;
  String _databaseState = 'Проверка не выполнялась';
  String _storageState = 'Проверка не выполнялась';
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final db = await AppDatabase.instance.database;
      await db.rawQuery('SELECT 1');
      _databaseState = 'SQLite доступна';
    } catch (e) { _databaseState = 'Ошибка SQLite: $e'; }
    try {
      final dir = await getApplicationSupportDirectory();
      final free = await dir.stat();
      _storageState = 'Папка приложения доступна: ${free.type.name}';
    } catch (e) { _storageState = 'Ошибка хранилища: $e'; }
    await _runtime.initialize();
    if (mounted) setState(() => _checking = false);
  }

  Widget _status(String title, String value, IconData icon) => Card(child: ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(value)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Диагностика')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      FilledButton.icon(onPressed: _checking ? null : _check, icon: const Icon(Icons.health_and_safety), label: Text(_checking ? 'Проверка…' : 'Запустить проверку')),
      const SizedBox(height: 12),
      _status('Локальная модель', _runtime.isLoaded ? 'Загружена: ${_runtime.modelName}' : (_runtime.modelPath == null ? 'Не выбрана' : 'Выбрана, но не загружена'), Icons.memory),
      _status('SQLite', _databaseState, Icons.storage),
      _status('Файловое хранилище', _storageState, Icons.folder),
      _status('GPU / Vulkan', _runtime.gpuInfo == null ? 'Данные ещё не получены' : '${_runtime.gpuInfo.gpuName ?? 'GPU не определён'} · Vulkan: ${_runtime.gpuInfo.vulkanSupported == true ? 'да' : 'нет'}', Icons.speed),
      if (_runtime.error != null) _status('Последняя ошибка Runtime', _runtime.error!, Icons.error_outline),
      const SizedBox(height: 8),
      Text('Диагностика проверяет доступность компонентов приложения. Она не является тестом качества генерации, температуры или стабильности нативного движка.', style: Theme.of(context).textTheme.bodySmall),
    ]),
  );
}
