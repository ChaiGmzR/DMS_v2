import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'update_config.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.tagName,
    required this.title,
    required this.notes,
    required this.releaseUrl,
    required this.downloadUrl,
    required this.assetName,
  });

  final String version;
  final String tagName;
  final String title;
  final String notes;
  final String releaseUrl;
  final String downloadUrl;
  final String assetName;
}

class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<UpdateInfo?> checkForUpdate() async {
    if (!UpdateConfig.checkOnStartup) return null;

    try {
      final response = await _client
          .get(
            UpdateConfig.latestReleaseUri,
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'DMS-v2-update-checker',
            },
          )
          .timeout(UpdateConfig.requestTimeout);

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return null;

      final tagName = '${json['tag_name'] ?? ''}'.trim();
      final latestVersion = normalizeVersion(tagName);
      if (!isNewerVersion(latestVersion, UpdateConfig.currentVersion)) {
        return null;
      }

      final assets = json['assets'] is List
          ? (json['assets'] as List).whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      final asset = _selectAsset(assets);
      final releaseUrl = '${json['html_url'] ?? ''}';

      return UpdateInfo(
        version: latestVersion,
        tagName: tagName,
        title: '${json['name'] ?? tagName}',
        notes: '${json['body'] ?? ''}',
        releaseUrl: releaseUrl,
        downloadUrl: '${asset?['browser_download_url'] ?? releaseUrl}',
        assetName: '${asset?['name'] ?? 'Release'}',
      );
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static bool isNewerVersion(String latest, String current) {
    final latestParts = _versionParts(latest);
    final currentParts = _versionParts(current);

    for (var i = 0; i < latestParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  @visibleForTesting
  static String normalizeVersion(String value) {
    final trimmed = value.trim();
    final withoutPrefix = trimmed.replaceFirst(RegExp('^[vV]'), '');
    return withoutPrefix.split('+').first.split('-').first;
  }

  static List<int> _versionParts(String value) {
    final parts = normalizeVersion(value).split('.');
    return List<int>.generate(3, (index) {
      if (index >= parts.length) return 0;
      return int.tryParse(parts[index]) ?? 0;
    });
  }

  static Map<String, dynamic>? _selectAsset(List<Map<String, dynamic>> assets) {
    if (assets.isEmpty) return null;

    bool matches(String name) {
      final lower = name.toLowerCase();
      return switch (defaultTargetPlatform) {
        TargetPlatform.android => lower.endsWith('.apk'),
        TargetPlatform.windows =>
          lower.endsWith('.zip') && lower.contains('windows'),
        _ => lower.endsWith('.apk'),
      };
    }

    for (final asset in assets) {
      if (matches('${asset['name'] ?? ''}')) return asset;
    }
    return assets.first;
  }
}
