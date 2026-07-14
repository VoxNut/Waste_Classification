import 'dart:io';

import 'package:waste_classification/data/models/classification_result.dart';

abstract interface class WasteClassifierService {
  Future<ClassificationResult> classify(File imageFile);
}

class ClassificationException implements Exception {
  const ClassificationException(this.code, [this.cause]);

  final ClassificationErrorCode code;
  final Object? cause;
}

enum ClassificationErrorCode {
  noConnection,
  timeout,
  invalidResponse,
  unavailable,
}
