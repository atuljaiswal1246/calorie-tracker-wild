import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calorie_tracker/services/experiment_service.dart';
import 'package:calorie_tracker/services/storage_service.dart';

void main() {
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    ExperimentService.init(storage);
  });

  test('assignment is stable for a user', () {
    storage.setUserId('user-123');
    final a = ExperimentService.variant('exp', const ['a', 'b', 'c']);
    final b = ExperimentService.variant('exp', const ['a', 'b', 'c']);
    expect(a, b);
    expect(['a', 'b', 'c'], contains(a));
  });

  test('streak display variant is one of the two buckets', () {
    expect(['compact', 'verbose'],
        contains(ExperimentService.streakDisplayVariant()));
  });

  test('unknown user falls back to a stable anon bucket', () {
    storage.setUserId(null);
    expect(ExperimentService.variant('exp', const ['x']), 'x');
    expect(ExperimentService.variant('exp', const []), '');
  });
}
