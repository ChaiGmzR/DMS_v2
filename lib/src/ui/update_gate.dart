import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.update});

  final UpdateInfo update;

  @override
  Widget build(BuildContext context) {
    final notes = update.notes.trim();

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
                'Nueva version: ${update.version}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (notes.isNotEmpty) ...[
                Text(notes, maxLines: 10, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
              ],
              Text(
                'Archivo: ${update.assetName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Mas tarde'),
        ),
        FilledButton.icon(
          onPressed: () => _openDownload(context),
          icon: const Icon(Icons.download),
          label: const Text('Descargar'),
        ),
      ],
    );
  }

  Future<void> _openDownload(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(update.downloadUrl);

    if (uri == null) {
      messenger.showSnackBar(
        snack('URL de descarga no disponible', error: true),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) {
      navigator.pop();
      return;
    }

    messenger.showSnackBar(snack('No se pudo abrir la descarga', error: true));
  }
}
