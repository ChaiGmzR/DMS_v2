import 'package:defect_ms_v2/src/core/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateService.isNewerVersion', () {
    test('detecta patch, minor y major superiores', () {
      expect(UpdateService.isNewerVersion('0.0.2', '0.0.1'), isTrue);
      expect(UpdateService.isNewerVersion('0.1.0', '0.0.9'), isTrue);
      expect(UpdateService.isNewerVersion('1.0.0', '0.9.9'), isTrue);
    });

    test('ignora prefijo v y no actualiza misma version', () {
      expect(UpdateService.isNewerVersion('v0.0.2', '0.0.2'), isFalse);
      expect(UpdateService.isNewerVersion('0.0.1', '0.0.2'), isFalse);
    });
  });
}
