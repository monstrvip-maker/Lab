import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class KnowledgeSearchHit {
  const KnowledgeSearchHit({required this.documentId, required this.title, required this.sourceName, required this.content, required this.score, required this.chunkIndex});
  final int documentId;
  final String title;
  final String sourceName;
  final String content;
  final double score;
  final int chunkIndex;
}

/// Offline document index. Retrieval uses TF-IDF/cosine-like lexical ranking;
/// it is deliberately not described as neural embeddings.
class KnowledgeIndexRepository {
  static final _stopWords = <String>{
    'это','как','для','что','или','при','над','под','его','её','они','она','оно',
    'the','and','for','with','from','that','this','are','was','were','you','your',
  };

  List<String> _terms(String text) => text.toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}_]+', unicode: true))
      .where((term) => term.length > 2 && !_stopWords.contains(term))
      .toList();

  String _checksum(String text) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(text)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<int> importText({required String title, required String sourceName, required String content}) async {
    final normalized = content.replaceAll('\r\n', '\n').trim();
    if (normalized.length < 20) throw const FormatException('В документе слишком мало текста.');
    final checksum = _checksum(normalized);
    final db = await AppDatabase.instance.database;
    final existing = await db.query('knowledge_documents', columns: ['id'], where: 'checksum = ?', whereArgs: [checksum], limit: 1);
    if (existing.isNotEmpty) return existing.first['id'] as int;
    final chunks = <String>[];
    const chunkSize = 1800;
    const overlap = 180;
    var offset = 0;
    while (offset < normalized.length) {
      var end = (offset + chunkSize).clamp(0, normalized.length).toInt();
      if (end < normalized.length) {
        final boundary = normalized.lastIndexOf(RegExp(r'[\n.!? ]'), end);
        if (boundary > offset + 900) end = boundary;
      }
      chunks.add(normalized.substring(offset, end).trim());
      if (end >= normalized.length) break;
      offset = (end - overlap).clamp(offset + 1, normalized.length).toInt();
    }
    final now = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      final id = await txn.insert('knowledge_documents', {
        'title': title.trim().isEmpty ? sourceName : title.trim(),
        'source_name': sourceName,
        'source_type': sourceName.toLowerCase().endsWith('.md') ? 'markdown' : 'text',
        'checksum': checksum,
        'chunk_count': chunks.length,
        'imported_at': now,
      });
      for (var i = 0; i < chunks.length; i++) {
        await txn.insert('knowledge_chunks', {
          'document_id': id, 'chunk_index': i, 'content': chunks[i],
          'token_text': _terms(chunks[i]).join(' '), 'created_at': now,
        });
      }
      return id;
    });
  }

  Future<List<KnowledgeSearchHit>> search(String query, {int limit = 12}) async {
    final terms = _terms(query).toSet();
    if (terms.isEmpty) return [];
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT c.document_id, c.chunk_index, c.content, c.token_text, d.title, d.source_name
      FROM knowledge_chunks c JOIN knowledge_documents d ON d.id = c.document_id
    ''');
    if (rows.isEmpty) return [];
    final documents = <String, int>{};
    for (final row in rows) {
      final termsInDoc = (row['token_text'] as String).split(' ').where((v) => v.isNotEmpty).toSet();
      for (final term in termsInDoc) {
        documents[term] = (documents[term] ?? 0) + 1;
      }
    }
    final hits = <KnowledgeSearchHit>[];
    for (final row in rows) {
      final text = row['token_text'] as String;
      final words = text.split(' ').where((v) => v.isNotEmpty).toList();
      if (words.isEmpty) continue;
      var score = 0.0;
      for (final term in terms) {
        final frequency = words.where((word) => word == term).length;
        if (frequency == 0) continue;
        final idf = 1 + (rows.length / (1 + (documents[term] ?? 0)));
        score += (frequency / words.length) * idf;
      }
      if (score > 0) hits.add(KnowledgeSearchHit(
        documentId: row['document_id'] as int,
        title: row['title'] as String,
        sourceName: row['source_name'] as String,
        content: row['content'] as String,
        score: score,
        chunkIndex: row['chunk_index'] as int,
      ));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList();
  }


  Future<List<Map<String, Object?>>> documents() async {
    final db = await AppDatabase.instance.database;
    return db.query('knowledge_documents', orderBy: 'imported_at DESC');
  }

  Future<void> deleteDocument(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('knowledge_documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> chunkCount() async {
    final db = await AppDatabase.instance.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM knowledge_chunks')) ?? 0;
  }

  Future<int> documentCount() async {
    final db = await AppDatabase.instance.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM knowledge_documents')) ?? 0;
  }
}
