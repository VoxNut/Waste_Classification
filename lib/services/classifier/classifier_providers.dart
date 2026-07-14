import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_classification/core/config/app_config.dart';
import 'package:waste_classification/services/classifier/api_classifier_service.dart';
import 'package:waste_classification/services/classifier/mock_classifier_service.dart';
import 'package:waste_classification/services/classifier/waste_classifier_service.dart';

final classifierServiceProvider = Provider<WasteClassifierService>((ref) {
  if (AppConfig.classifierMode == ClassifierMode.api) {
    return ApiClassifierService(baseUrl: AppConfig.apiBaseUrl);
  }
  return const MockClassifierService();
});
