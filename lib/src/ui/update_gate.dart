import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_constants.dart';
import '../core/update_service.dart';
import 'ui_helpers.dart';

class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child, this.service});

  final Widget child;
  final UpdateService? service;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  static bool _checkedThisSession = false;
  late final UpdateService _service;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? UpdateService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _checkForUpdate() async {
    if (_checkedThisSession || _dialogOpen || !mounted) return;
    _checkedThisSession = true;

    final update = await _service.checkForUpdate();
    if (update == null || !mounted) return;

    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateDialog(update: update),
    );
    _dialogOpen = false;
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.update});

  final UpdateInfo update;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  int _receivedBytes = 0;
  int? _totalBytes;

  @override
  Widget build(BuildContext context) {
    final notes = widget.update.notes.trim();
    final progress = _totalBytes == null || _totalBytes == 0
        ? null
        : _receivedBytes / _totalBytes!;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.system_update_alt),
          SizedBox(width: 10),
          Expanded(child: Text('Actualizacion disponible')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version instalada: ${AppConstants.appVersion}'),
              const SizedBox(height: 4),
              Text(
                'Nueva version: ${widget.update.version}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (notes.isNotEmpty) ...[
                Text(notes, maxLines: 10, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
              ],
              Text(
                'Archivo: ${widget.update.assetName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              if (_downloading) ...[
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Text(
                  _downloadStatus,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else
                Text(
                  'La descarga se realiza dentro de DMS y abre el instalador sin navegador.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _downloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Mas tarde'),
        ),
        FilledButton.icon(
          onPressed: _downloading ? null : _downloadAndOpen,
          icon: Icon(_downloading ? Icons.downloading : Icons.download),
          label: Text(_downloading ? 'Descargando' : 'Descargar'),
        ),
      ],
    );
  }

  String get _downloadStatus {
    if (_totalBytes != null && _totalBytes! > 0) {
      return '${_formatBytes(_receivedBytes)} de ${_formatBytes(_totalBytes!)}';
    }
    return '${_formatBytes(_receivedBytes)} descargados';
  }

  Future<void> _downloadAndOpen() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(widget.update.downloadUrl);

    if (uri == null) {
      messenger.showSnackBar(
        snack('URL de descarga no disponible', error: true),
      );
      return;
    }

    setState(() {
      _downloading = true;
      _receivedBytes = 0;
      _totalBytes = null;
    });

    final client = http.Client();
    IOSink? sink;

    try {
      final request = http.Request('GET', uri)
        ..headers['User-Agent'] = 'DMS-v2-updater';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final tempDir = await getTemporaryDirectory();
      final updateDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}dms_updates',
      );
      if (!await updateDir.exists()) {
        await updateDir.create(recursive: true);
      }

      final fileName = _safeFileName(widget.update.assetName);
      final file = File('${updateDir.path}${Platform.pathSeparator}$fileName');
      if (await file.exists()) {
        await file.delete();
      }

      sink = file.openWrite();
      if (mounted) {
        setState(() => _totalBytes = response.contentLength);
      }

      await for (final chunk in response.stream) {
        sink.add(chunk);
        if (!mounted) continue;
        setState(() => _receivedBytes += chunk.length);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (!mounted) return;
      setState(() => _downloading = false);

      final result = await OpenFilex.open(
        file.path,
        type: _mimeType(file.path),
      );
      if (!mounted) return;

      if (result.type == ResultType.done) {
        navigator.pop();
        return;
      }

      messenger.showSnackBar(snack(_friendlyOpenError(result), error: true));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        snack('No se pudo descargar la actualizacion', error: true),
      );
    } finally {
      client.close();
      await sink?.close();
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  static String _safeFileName(String value) {
    final fallback = value.trim().isEmpty ? 'dms_update' : value.trim();
    return fallback.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  static String? _mimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.apk')) {
      return 'application/vnd.android.package-archive';
    }
    if (lower.endsWith('.exe')) return 'application/x-msdownload';
    if (lower.endsWith('.zip')) return 'application/zip';
    return null;
  }

  static String _friendlyOpenError(OpenResult result) {
    return switch (result.type) {
      ResultType.permissionDenied =>
        'Permiso denegado para abrir el instalador',
      ResultType.fileNotFound => 'No se encontro el archivo descargado',
      ResultType.noAppToOpen =>
        'No hay una aplicacion para abrir el instalador',
      ResultType.error => 'No se pudo abrir el instalador',
      ResultType.done => 'Instalador abierto',
    };
  }

  static String _formatBytes(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}
