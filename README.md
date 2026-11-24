# Prompt Lab AI

Локальная AI-платформа для Android: создание и анализ промтов, библиотека знаний, локальные модели Qwen, агенты и управление проектами.

## Foundation
Этот коммит содержит стартовый Flutter-каркас и документацию архитектуры. Это ещё не готовая AI-система: локальный Runtime, SQLite, загрузчик моделей и агентный движок будут подключаться отдельными этапами.

## Стек
- Flutter / Dart — интерфейс и прикладная логика.
- Kotlin — нативные Android-интеграции.
- SQLite — структурированные данные.
- Local AI Runtime — сменный адаптер; основной кандидат для GGUF — llama.cpp.
- Локальные модели — без обязательных внешних AI API.

## Запуск
Требуется установленный Flutter SDK и Android SDK.

```bash
flutter create .
flutter pub get
flutter analyze
flutter run
```

Сборка APK:

```bash
flutter build apk --debug
flutter build apk --release
```

## Документация
- [Архитектура](docs/ARCHITECTURE.md)
- [План реализации](docs/ROADMAP.md)

## Статус
Foundation 0.1 — базовая навигация и экраны-заготовки. Реальная работа AI, сохранение данных и синхронизация с Android Share пока не реализованы.
