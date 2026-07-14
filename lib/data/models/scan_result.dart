class ScanResult {
  const ScanResult({
    required this.id,
    required this.imagePath,
    required this.scannedAt,
    required this.categoryId,
    required this.modelLabel,
    required this.confidence,
  });

  final String id;
  final String imagePath;
  final DateTime scannedAt;
  final String categoryId;
  final String modelLabel;
  final double confidence;

  Map<String, Object?> toMap() => {
    'id': id,
    'image_path': imagePath,
    'scanned_at': scannedAt.toUtc().toIso8601String(),
    'category_id': categoryId,
    'model_label': modelLabel,
    'confidence': confidence,
  };
}
