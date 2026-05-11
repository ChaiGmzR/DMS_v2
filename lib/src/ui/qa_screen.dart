import 'package:flutter/material.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import 'ui_helpers.dart';

class QaScreen extends StatefulWidget {
  const QaScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SectionHeader(
                title: 'Pendientes de validacion QA',
                subtitle: '${_items.length} reparaciones esperando inspeccion',
                trailing: IconButton(
                  tooltip: 'Actualizar',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                    ? const Center(
                        child: Text('No hay reparaciones pendientes de QA'),
                      )
                    : _qaList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qaList() {
    if (!isCompact(context)) {
      return SingleChildScrollView(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _items
              .map((item) => SizedBox(width: 380, child: _qaCard(item)))
              .toList(),
        ),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _qaCard(_items[index]),
    );
  }

  Widget _qaCard(Map<String, dynamic> item) {
    final repairId = '${item['repair_id'] ?? ''}';
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item['codigo'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text('${item['defecto'] ?? ''}'),
            const SizedBox(height: 6),
            Text('Modelo: ${item['modelo'] ?? 'N/A'}'),
            Text('Tecnico: ${item['tecnico'] ?? ''}'),
            if (item['accion_correctiva'] != null)
              Text('Accion: ${item['accion_correctiva']}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.appState.user?.canQuality == true
                      ? () => _reject(repairId)
                      : null,
                  icon: const Icon(Icons.close),
                  label: const Text('Rechazar'),
                ),
                FilledButton.icon(
                  onPressed: widget.appState.user?.canQuality == true
                      ? () => _approve(repairId)
                      : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Aprobar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await widget.appState.api.getQaPending();
      if (mounted) setState(() => _items = items);
    } on DmsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack(error.message, error: true));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(String repairId) async {
    final obs = await _observationsDialog(
      title: 'Aprobar reparacion',
      required: false,
    );
    if (obs == null) return;
    try {
      await widget.appState.api.approveQa(repairId, obs);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack('Reparacion aprobada'));
      }
    } on DmsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack(error.message, error: true));
      }
    }
  }

  Future<void> _reject(String repairId) async {
    final obs = await _observationsDialog(
      title: 'Rechazar reparacion',
      required: true,
    );
    if (obs == null) return;
    try {
      await widget.appState.api.rejectQa(repairId, obs);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack('Reparacion rechazada'));
      }
    } on DmsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack(error.message, error: true));
      }
    }
  }

  Future<String?> _observationsDialog({
    required String title,
    required bool required,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Observaciones QA'),
            minLines: 3,
            maxLines: 5,
            validator: (value) {
              if (required && (value == null || value.trim().isEmpty)) {
                return 'Requerido';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}
