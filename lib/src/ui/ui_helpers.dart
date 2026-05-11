import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const lineasDms = ['M1', 'M2', 'M3', 'M4', 'DP1', 'DP2', 'DP3', 'Harness'];
const areasDms = [
  'SMD',
  'IMD',
  'Ensamble',
  'Mantenimiento',
  'Micom',
  'Calidad',
  'Area de Proveedor',
];
const tiposInspeccionDms = ['ICT', 'FCT', 'Packing', 'Visual'];

const defectosCatalogo = [
  'AL REVES',
  'BOTON DURO',
  'COMPONENTE EXTRA',
  'CONTAMINADO',
  'CORTO',
  'DAÑADO',
  'DESALINEADO',
  'ETIQUETA EQUIVOCADA',
  'EQUIVOCADO',
  'EXCESO DE COATING',
  'EXCESO SOLDADURA',
  'FALTANTE',
  'FALTANTE DE COATING',
  'FALTANTE SOLDADURA',
  'FLUX',
  'INVERTIDO',
  'LED AMARILLO',
  'LEVANTADO',
  'MAL CORTE',
  'MAL ENSAMBLE',
  'MALA FUSION',
  'MALA INSERCION',
  'MATERIAL MAL IDENTIFICADO',
  'PANDEADA',
  'PIN CORTO',
  'PIN LARGO',
  'POSICION EQUIVOCADA',
  'PROGRAMACION EQUIVOCADA',
  'PROGRAMACION FALTANTE',
  'QUEBRADO',
  'RAYADO',
  'REBABA',
  'RESIDUO IMD',
  'SCRAP',
  'SCRAP ANALISIS',
  'SCRAP MR',
  'SERIGRAFIA BORROSA',
  'SERIGRAFIA CORRIDA',
  'SERIGRAFIA FALTANTE',
  'SILICON',
  'SOLDER BALL',
];

bool isCompact(BuildContext context) => MediaQuery.sizeOf(context).width < 720;
bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 1100;

bool get supportsCameraScanner {
  return kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

String todayIso() => DateFormat('yyyy-MM-dd').format(DateTime.now());

String mysqlDateTime(DateTime date) =>
    DateFormat('yyyy-MM-dd HH:mm:ss').format(date);

String formatDateOnly(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value.split(' ').first;
  return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
}

String formatTimeOnly(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    final parts = value.split(' ');
    return parts.length > 1 ? parts[1].split('.').first : '';
  }
  return DateFormat('HH:mm').format(parsed.toLocal());
}

String statusLabel(String status) {
  return switch (status) {
    'Pendiente_Reparacion' => 'Pendiente',
    'En_Reparacion' => 'En reparacion',
    'Reparado' => 'Reparado',
    'Rechazado' => 'Rechazado',
    'Aprobado' => 'Aprobado',
    _ => status,
  };
}

Color statusColor(BuildContext context, String status) {
  return switch (status) {
    'Pendiente_Reparacion' => Theme.of(context).colorScheme.tertiary,
    'En_Reparacion' => Theme.of(context).colorScheme.secondary,
    'Reparado' => const Color(0xFF7C9D4B),
    'Aprobado' => const Color(0xFF4DA36A),
    'Rechazado' => const Color(0xFFE05A48),
    _ => Theme.of(context).colorScheme.outline,
  };
}

SnackBar snack(String message, {bool error = false}) {
  return SnackBar(
    content: Text(message),
    backgroundColor: error ? const Color(0xFFB33A2F) : const Color(0xFF2F6E42),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(context, status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          statusLabel(status),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
