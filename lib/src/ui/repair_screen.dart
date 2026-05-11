import 'package:flutter/material.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import 'ui_helpers.dart';

class RepairScreen extends StatefulWidget {
  const RepairScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<RepairScreen> createState() => _RepairScreenState();
}

class _RepairScreenState extends State<RepairScreen> {
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _inProcess = [];
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
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                SectionHeader(
                  title: 'Flujo de reparacion',
                  subtitle:
                      'Pendientes: ${_pending.length} | En proceso: ${_inProcess.length}',
                  trailing: IconButton(
                    tooltip: 'Actualizar',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.pending_actions), text: 'Pendientes'),
                    Tab(icon: Icon(Icons.engineering), text: 'En proceso'),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          children: [
                            _repairList(_pending, pending: true),
                            _repairList(_inProcess, pending: false),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _repairList(
    List<Map<String, dynamic>> items, {
    required bool pending,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          pending
              ? 'No hay defectos pendientes'
              : 'No hay reparaciones en proceso',
        ),
      );
    }

    if (!isCompact(context)) {
      return SingleChildScrollView(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
                  width: 360,
                  child: _repairCard(item, pending: pending),
                ),
              )
              .toList(),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) =>
          _repairCard(items[index], pending: pending),
    );
  }

  Widget _repairCard(Map<String, dynamic> item, {required bool pending}) {
    final defectId = '${item['id'] ?? item['defect_id'] ?? ''}';
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
            if (item['ubicacion'] != null)
              Text('Ubicacion: ${item['ubicacion']}'),
            if (item['tecnico'] != null) Text('Tecnico: ${item['tecnico']}'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: pending
                  ? FilledButton.icon(
                      onPressed: widget.appState.user?.canRepair == true
                          ? () => _startRepair(defectId)
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Iniciar'),
                    )
                  : FilledButton.icon(
                      onPressed: widget.appState.user?.canRepair == true
                          ? () => _finishRepair(defectId, item)
                          : null,
                      icon: const Icon(Icons.done_all),
                      label: const Text('Finalizar'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pending = await widget.appState.api.getRepairPending();
      final inProcess = await widget.appState.api.getRepairInProcess();
      if (mounted) {
        setState(() {
          _pending = pending;
          _inProcess = inProcess;
        });
      }
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

  Future<void> _startRepair(String defectId) async {
    try {
      await widget.appState.api.startRepair(defectId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack('Reparacion iniciada'));
      }
    } on DmsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack(error.message, error: true));
      }
    }
  }

  Future<void> _finishRepair(String defectId, Map<String, dynamic> item) async {
    final result = await showDialog<_RepairFormResult>(
      context: context,
      builder: (_) => const _FinishRepairDialog(),
    );
    if (result == null) return;

    try {
      var repairId = '${item['repair_id'] ?? ''}';
      if (repairId.isEmpty) {
        final history = await widget.appState.api.getRepairHistory(defectId);
        if (history.isNotEmpty) repairId = '${history.first['id'] ?? ''}';
      }
      if (repairId.isEmpty) {
        throw DmsException('No se encontro el ID de reparacion');
      }

      await widget.appState.api.finishRepair(
        repairId: repairId,
        accionCorrectiva: result.accionCorrectiva,
        materialesUsados: result.materialesUsados,
        observaciones: result.observaciones,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack('Reparacion finalizada'));
      }
    } on DmsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack(error.message, error: true));
      }
    }
  }
}

class _FinishRepairDialog extends StatefulWidget {
  const _FinishRepairDialog();

  @override
  State<_FinishRepairDialog> createState() => _FinishRepairDialogState();
}

class _FinishRepairDialogState extends State<_FinishRepairDialog> {
  final _formKey = GlobalKey<FormState>();
  final _accionController = TextEditingController();
  final _materialesController = TextEditingController();
  final _observacionesController = TextEditingController();

  @override
  void dispose() {
    _accionController.dispose();
    _materialesController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Finalizar reparacion'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _accionController,
                decoration: const InputDecoration(
                  labelText: 'Accion correctiva',
                ),
                minLines: 2,
                maxLines: 4,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _materialesController,
                decoration: const InputDecoration(
                  labelText: 'Materiales usados',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _observacionesController,
                decoration: const InputDecoration(labelText: 'Observaciones'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _RepairFormResult(
                accionCorrectiva: _accionController.text.trim(),
                materialesUsados: _materialesController.text.trim(),
                observaciones: _observacionesController.text.trim(),
              ),
            );
          },
          child: const Text('Finalizar'),
        ),
      ],
    );
  }
}

class _RepairFormResult {
  const _RepairFormResult({
    required this.accionCorrectiva,
    required this.materialesUsados,
    required this.observaciones,
  });

  final String accionCorrectiva;
  final String materialesUsados;
  final String observaciones;
}
