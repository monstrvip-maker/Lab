import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../ai/runtime/local_ai_runtime.dart';

class ModelManagerScreen extends StatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen> {
  final _runtime = LocalAiRuntime.instance;

  @override
  void initState() {
    super.initState();
    _runtime.initialize();
  }

  Future<void> _chooseModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gguf'],
      withData: false,
    );
    if (!mounted || result == null) return;

    final selectedPath = result.files.single.path;
    if (selectedPath == null) {
      _showMessage('Не удалось получить путь к выбранному файлу.');
      return;
    }

    try {
      await _runtime.unloadModel();
      await _runtime.importModel(selectedPath);
      if (mounted) _showMessage('Модель скопирована в защищённое хранилище приложения.');
    } catch (error) {
      if (mounted) _showMessage('Ошибка импорта: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _runtime,
      builder: (context, _) {
        final gpu = _runtime.gpuInfo;
        return Scaffold(
          appBar: AppBar(title: const Text('Менеджер моделей')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.memory, size: 28),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Локальный AI Runtime',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _runtime.isLoaded
                            ? 'Модель загружена и готова к работе'
                            : _runtime.isLoading
                                ? 'Загрузка модели в память…'
                                : 'Модель не загружена',
                      ),
                      if (_runtime.modelName != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _runtime.modelName!,
                          style: TextStyle(color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                      if (gpu != null) ...[
                        const SizedBox(height: 12),
                        Text('Устройство: ${gpu.gpuName ?? 'не определено'}'),
                        Text('Vulkan: ${gpu.vulkanSupported == true ? 'доступен' : 'не доступен'}'),
                        Text(
                          'Свободная RAM: ${((gpu.freeRamBytes ?? 0) / 1024 / 1024).round()} МБ',
                        ),
                      ],
                      if (_runtime.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _runtime.error!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: _runtime.isLoading ? null : _chooseModel,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Выбрать GGUF'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _runtime.isLoading || _runtime.modelPath == null
                                ? null
                                : _runtime.loadModel,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Загрузить'),
                          ),
                          if (_runtime.isLoaded)
                            OutlinedButton.icon(
                              onPressed: _runtime.unloadModel,
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: const Text('Выгрузить'),
                            ),
                        ],
                      ),
                      if (_runtime.isLoading) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Рекомендации для телефона с 8 ГБ RAM',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Qwen2.5 1.5B Instruct · GGUF Q4_K_M'),
                      SizedBox(height: 6),
                      Text('Более лёгкий вариант для первого запуска и проверки скорости.'),
                      Divider(height: 22),
                      Text('Qwen2.5 3B Instruct · GGUF Q4_K_M'),
                      SizedBox(height: 6),
                      Text('Основной кандидат для более сложных задач. Потребляет больше памяти.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Выберите файл .gguf один раз. Приложение сохранит его во внутреннем хранилище и будет автоматически загружать модель при следующем запуске. Во время теста используется контекст 2048 токенов.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_runtime.modelPath != null)
                FutureBuilder<int>(
                  future: File(_runtime.modelPath!).length(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final sizeMb = snapshot.data! / 1024 / 1024;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Размер файла: ${sizeMb.toStringAsFixed(0)} МБ'),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
