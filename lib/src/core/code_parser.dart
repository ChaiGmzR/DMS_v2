import 'dart:convert';

const _partCodeKeys = {
  'codigo',
  'code',
  'part',
  'partcode',
  'partno',
  'partnumber',
  'part_no',
  'part_number',
  'no_parte',
  'noparte',
  'numero_parte',
  'material',
};

String? extractPartCode(String raw) {
  final input = raw.trim();
  if (input.isEmpty) return null;

  final candidates = <String>[];

  void addCandidate(Object? value) {
    final text = '$value'.trim();
    if (text.isNotEmpty) candidates.add(text);
  }

  try {
    final decoded = jsonDecode(input);
    if (decoded is Map<String, dynamic>) {
      for (final entry in decoded.entries) {
        if (_isPartCodeKey(entry.key)) addCandidate(entry.value);
      }
    } else if (decoded is List) {
      for (final item in decoded) {
        addCandidate(item);
      }
    }
  } catch (_) {
    // El QR puede ser texto plano, URL o formato etiqueta; se procesa abajo.
  }

  final uri = Uri.tryParse(input);
  if (uri != null) {
    for (final entry in uri.queryParameters.entries) {
      if (_isPartCodeKey(entry.key)) addCandidate(entry.value);
    }
    for (final segment in uri.pathSegments.reversed) {
      addCandidate(segment);
    }
  }

  for (final part in input.split(RegExp(r'[\r\n;|,]'))) {
    final pieces = part.split(RegExp(r'[:=]'));
    if (pieces.length >= 2 && _isPartCodeKey(pieces.first)) {
      addCandidate(pieces.sublist(1).join(':'));
    }
    addCandidate(part);
  }

  addCandidate(input);

  final preferred = <String>[];
  final fallback = <String>[];
  for (final candidate in candidates) {
    final tokens = _codeTokens(candidate);
    preferred.addAll(tokens.where((token) => token.startsWith('EBR')));
    fallback.addAll(tokens.where((token) => !token.startsWith('EBR')));
  }

  if (preferred.isNotEmpty) return preferred.first;
  if (fallback.isNotEmpty) return fallback.first;
  return null;
}

bool _isPartCodeKey(String key) {
  final normalized = key.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9_]'),
    '',
  );
  return _partCodeKeys.contains(normalized);
}

List<String> _codeTokens(String value) {
  final upper = value.trim().toUpperCase();
  final ebrMatches = RegExp(
    r'EBR[A-Z0-9_-]{6,}',
  ).allMatches(upper).map((match) => match.group(0)!).toList();
  if (ebrMatches.isNotEmpty) return ebrMatches;

  final normalized = upper.replaceAll(RegExp(r'[^A-Z0-9_-]'), ' ');
  return normalized.split(RegExp(r'\s+')).where(_isLikelyPartCode).toList();
}

bool _isLikelyPartCode(String token) {
  if (token.length < 6) return false;
  if (RegExp(r'^[A-Z_]+$').hasMatch(token)) return false;
  const blocked = {
    'HTTP',
    'HTTPS',
    'WWW',
    'CODIGO',
    'CODE',
    'PART',
    'PARTNO',
    'PARTNUMBER',
    'MATERIAL',
  };
  return !blocked.contains(token);
}
