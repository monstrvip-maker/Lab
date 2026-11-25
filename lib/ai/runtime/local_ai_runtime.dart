import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single-owner runtime for the native llama controller.
/// All inference requests are serialized because the native controller supports
/// only one active generation at a time.
class LocalAiRuntime extends ChangeNotifier {
  LocalAiRuntime._();

  static final LocalAiRuntime instance = LocalAiRuntime._();

  static const _modelPathKey = 'local_ai_model_path';
  LlamaController? _controller;
  String? _modelPath;
  String? _error;
  bool _isLoading = false;
  bool _isLoaded = false;
  bool _isGenerating = false;
  dynamic _gpuInfo;
  Future<void> _generationTail = Future<void>.value();

  String? get modelPath => _modelPath;
  String? get modelName => _modelPath == null ? null : path.basename(_modelPath!);
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  bool get isGenerating => _isGenerating;
  dynamic get gpuInfo => _gpuInfo;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final savedPath = preferences.getString(_modelPathKey);
    if (savedPath != null && await File(savedPath).exists()) {
      _modelPath = savedPath;
    } else if (savedPath != null) {
      await preferences.remove(_modelPathKey);
    }
    notifyListeners();
  }

  Future<void> importModel(String sourcePath) async {
    final source = File(sourcePath);
    if (!sourcePath.toLowerCase().endsWith('.gguf')) {
      throw const FormatException('Поддерживаются только модели в формате GGUF.');
    }
    if (!await source.exists()) throw FileSystemException('Файл модели не найден.', sourcePath);
    final supportDirectory = await getApplicationSupportDirectory();
    final modelsDirectory = Directory(path.join(supportDirectory.path, 'models'));
    await modelsDirectory.create(recursive: true);
    final safeName = path.basename(sourcePath).replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final destination = File(path.join(modelsDirectory.path, '${DateTime.now().microsecondsSinceEpoch}_$safeName'));
    await source.copy(destination.path);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_modelPathKey, destination.path);
    _modelPath = destination.path;
    _error = null;
    notifyListeners();
  }

  Future<void> detectDevice() async {
    try {
      _controller ??= LlamaController();
      _gpuInfo = await _controller!.detectGpu();
      _error = null;
    } catch (error) {
      _error = 'Не удалось определить ускорение: $error';
    }
    notifyListeners();
  }

  Future<void> loadModel() async {
    if (_modelPath == null) {
      _error = 'Сначала выберите файл модели GGUF.';
      notifyListeners();
      return;
    }
    if (_isLoaded || _isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _controller ??= LlamaController();
      _gpuInfo ??= await _controller!.detectGpu();
      final gpuLayers = _gpuInfo?.recommendedGpuLayers as int? ?? 0;
      await _controller!.loadModel(
        modelPath: _modelPath!,
        threads: 4,
        contextSize: 2048,
        gpuLayers: gpuLayers,
      );
      _isLoaded = true;
    } catch (error) {
      _error = 'Не удалось загрузить GGUF-модель. Проверьте целостность файла и свободную память. $error';
      _isLoaded = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<String> generateChat({
    required List<ChatMessage> messages,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async* {
    final previous = _generationTail;
    final release = Completer<void>();
    _generationTail = release.future;
    await previous;

    try {
      final controller = _controller;
      if (!_isLoaded || controller == null) {
        throw StateError('Локальная модель не загружена. Откройте менеджер моделей.');
      }
      _isGenerating = true;
      _error = null;
      notifyListeners();
      try {
        yield* controller.generateChat(
          messages: messages,
          template: 'chatml',
          maxTokens: maxTokens,
          temperature: temperature,
        );
      } catch (error) {
        final details = error.toString();
        // Qwen instruct GGUFs use ChatML. If the plugin's chat-template
        // adapter fails, retry once with the equivalent raw prompt so the
        // native tokenizer receives the actual model control tokens.
        if (details.toLowerCase().contains('decode prompt') &&
            (modelName?.toLowerCase().contains('qwen') ?? false)) {
          final rawPrompt = messages.map((message) {
            final role = message.role == 'system' || message.role == 'assistant'
                ? message.role
                : 'user';
            return '<|im_start|>$role\n${message.content.trim()}<|im_end|>\n';
          }).join() + '<|im_start|>assistant\n';
          try {
            yield* controller.generate(
              prompt: rawPrompt,
              maxTokens: maxTokens,
              temperature: temperature,
            );
          } catch (fallbackError) {
            throw StateError(
              'Не удалось обработать запрос ни через ChatML, ни через прямой '
              'формат Qwen. Первичная ошибка: $details; повторная попытка: $fallbackError. '
              'Проверьте, что выбрана именно Instruct GGUF-модель, а не Base.',
            );
          }
        } else {
          rethrow;
        }
      }
    } finally {
      _isGenerating = false;
      release.complete();
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (_isGenerating) await _controller?.stop();
  }

  Future<void> unloadModel() async {
    // Wait until any queued generation has released the native controller.
    await _generationTail;
    final controller = _controller;
    _controller = null;
    _isLoaded = false;
    if (controller != null) await controller.dispose();
    notifyListeners();
  }
}
