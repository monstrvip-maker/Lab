import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AgentRunRecord {
  const AgentRunRecord({
    required this.task,
    required this.result,
    required this.createdAt,
  });

  final String task;
  final String result;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'task': task,
        'result': result,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AgentRunRecord.fromJson(Map<String, dynamic> json) {
    return AgentRunRecord(
      task: json['task'] as String? ?? '',
      result: json['result'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class AgentRunHistory {
  static const _key = 'agent_run_history_v1';
  static const _maxRecords = 30;

  static Future<List<AgentRunRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AgentRunRecord.fromJson)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(String task, String result) async {
    if (result.trim().isEmpty) return;
    final records = await load();
    records.insert(
      0,
      AgentRunRecord(task: task, result: result, createdAt: DateTime.now()),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(records.take(_maxRecords).map((record) => record.toJson()).toList()),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
