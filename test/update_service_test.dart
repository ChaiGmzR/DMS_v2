import 'dart:convert';

import 'package:defect_ms_v2/src/core/update_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

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

  group('UpdateService.checkForUpdate', () {
    test('en Windows prefiere EXE sobre ZIP y APK', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final service = _serviceWithReleaseAssets([
        _asset('DMS_v2_windows_1.0.6_x64.zip'),
        _asset('DMS_v2_mobile_1.0.6.apk'),
        _asset('DMS_v2_windows_1.0.6_x64.exe'),
      ]);

      final update = await service.checkForUpdate();

      expect(update?.assetName, 'DMS_v2_windows_1.0.6_x64.exe');
    });

    test('en Android selecciona APK', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final service = _serviceWithReleaseAssets([
        _asset('DMS_v2_windows_1.0.6_x64.exe'),
        _asset('DMS_v2_mobile_1.0.6.apk'),
      ]);

      final update = await service.checkForUpdate();

      expect(update?.assetName, 'DMS_v2_mobile_1.0.6.apk');
    });
  });
}

UpdateService _serviceWithReleaseAssets(List<Map<String, dynamic>> assets) {
  return UpdateService(
    client: MockClient(
      (_) async => http.Response(
        jsonEncode([
          {
            'draft': false,
            'prerelease': false,
            'tag_name': 'v1.0.6',
            'name': 'Version 1.0.6',
            'body': 'Notas',
            'html_url':
                'https://github.com/ChaiGmzR/DMS_v2/releases/tag/v1.0.6',
            'assets': assets,
          },
        ]),
        200,
      ),
    ),
  );
}

Map<String, dynamic> _asset(String name) {
  return {
    'name': name,
    'browser_download_url':
        'https://github.com/ChaiGmzR/DMS_v2/releases/download/$name',
  };
}
