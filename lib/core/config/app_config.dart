enum ClassifierMode { mock, api }

abstract final class AppConfig {
  static const String _mode = String.fromEnvironment(
    'CLASSIFIER_MODE',
    defaultValue: 'api',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'WASTE_API_BASE_URL',
    defaultValue: 'https://voxnuts947-waste-classification-api.hf.space',
  );

  static const String appVersion = '1.0.8';

  static ClassifierMode get classifierMode {
    if (_mode.toLowerCase() == 'api' && apiBaseUrl.trim().isNotEmpty) {
      return ClassifierMode.api;
    }
    return ClassifierMode.mock;
  }
}
