class PromptRecord {
  const PromptRecord({
    this.id,
    required this.title,
    required this.originalText,
    this.improvedText,
    this.category = 'Без категории',
    this.sourceUrl,
    this.analysisJson,
    this.projectId,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String title;
  final String originalText;
  final String? improvedText;
  final String category;
  final String? sourceUrl;
  final String? analysisJson;
  final int? projectId;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PromptRecord.fromMap(Map<String, Object?> map) {
    return PromptRecord(
      id: map['id'] as int?,
      title: map['title'] as String,
      originalText: map['original_text'] as String,
      improvedText: map['improved_text'] as String?,
      category: map['category'] as String? ?? 'Без категории',
      sourceUrl: map['source_url'] as String?,
      analysisJson: map['analysis_json'] as String?,
      projectId: map['project_id'] as int?,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() => {
        'title': title,
        'original_text': originalText,
        'improved_text': improvedText,
        'category': category,
        'source_url': sourceUrl,
        'analysis_json': analysisJson,
        'project_id': projectId,
        'is_favorite': isFavorite ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
