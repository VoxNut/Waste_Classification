import 'package:flutter_test/flutter_test.dart';
import 'package:waste_classification/core/config/app_config.dart';

void main() {
  test('uses the live API by default', () {
    expect(AppConfig.classifierMode, ClassifierMode.api);
    expect(AppConfig.apiBaseUrl, startsWith('https://'));
    expect(AppConfig.apiBaseUrl, isNot(endsWith('/predict')));
  });
}
