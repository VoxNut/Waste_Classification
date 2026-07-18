import 'package:flutter_test/flutter_test.dart';
import 'package:waste_classification/core/config/app_config.dart';

void main() {
  test('uses the Hugging Face Space API by default', () {
    expect(AppConfig.classifierMode, ClassifierMode.api);
    expect(
      AppConfig.apiBaseUrl,
      'https://voxnuts947-waste-classification-api.hf.space',
    );
    expect(AppConfig.apiBaseUrl, isNot(endsWith('/predict')));
  });
}
