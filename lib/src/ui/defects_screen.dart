import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import 'ui_helpers.dart';

class DefectsScreen extends StatefulWidget {
  const DefectsScreen({
    super.key,
    required this.appState,
    this.navigationMenu,
    this.showOwnChrome = true,
  });

  final AppState appState;
  final Widget? navigationMenu;
  final bool showOwnChrome;

  @override
  State<DefectsScreen> createState() => _DefectsScreenState();
}

class _DefectsScreenState extends State<DefectsScreen> {
  static const _bg = Color(0xFF30313E);
  static const _panel = Color(0xFF333541);
  static const _header = Color(0xFF122C4B);
  static const _line = Color(0xFF209ADF);
  static const _green = Color(0xFF456B35);
  static const _red = Color(0xFFE84B43);

  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  final _ubicacionController = TextEditingController();
  final _modeloController = TextEditingController();
  final _codigoFiltroController = TextEditingController();
  late final MobileScannerController _scannerController;

  List<DefectItem> _defects = [];
  bool _loading = false;
  bool _saving = false;
  bool _listExpanded = false;
  bool _scanLocked = false;

  DateTime _fecha = DateTime.now();
  String? _linea;
  String? _defecto;
  String? _area;
  String _tipoInspeccion = 'Visual';
  String _fechaInicio = todayIso();
  String _fechaFin = todayIso();
  String? _lineaFiltro;
  String? _defectoFiltro;
  double _zoom = 0;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      ],
    );
    _load();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _ubicacionController.dispose();
    _modeloController.dispose();
    _codigoFiltroController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final portrait = width < 820;
    final body = portrait ? _portraitLayout() : _landscapeLayout();

    if (!widget.showOwnChrome) {
      return body;
    }

    return ColoredBox(
      color: _bg,
      child: SafeArea(
        child: Column(
          children: [
            _topBar(portrait: portrait),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _topBar({required bool portrait}) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _line, width: 2)),
      ),
      child: SizedBox(
        height: portrait ? 68 : 60,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: portrait ? 18 : 16),
          child: Row(
            children: [
              Container(
                width: portrait ? 44 : 42,
                height: portrait ? 44 : 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A8043),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF1CC96F), width: 2),
                ),
                child: const Icon(Icons.factory_outlined, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DMS',
                    style: TextStyle(
                      fontSize: portrait ? 20 : 22,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  Text(
                    portrait ? 'Defect Management' : 'Defect Management System',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB9D6DA),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (!portrait) ...[
                SizedBox(
                  height: 40,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _red),
                    onPressed: _clearForm,
                    child: const Text('Limpiar'),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 40,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _green),
                    onPressed:
                        widget.appState.user?.canCapture == true && !_saving
                        ? _saveDefect
                        : null,
                    child: const Text('Capturar'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (widget.navigationMenu != null) widget.navigationMenu!,
              IconButton.outlined(
                tooltip: 'Cerrar sesion',
                onPressed: widget.appState.logout,
                icon: const Icon(Icons.logout),
                color: Colors.white,
                style: IconButton.styleFrom(
                  side: const BorderSide(color: _line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _portraitLayout() {
    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(40, 12, 40, 128),
            child: Column(
              children: [
                _cameraFrame(height: 445, large: true),
                const SizedBox(height: 86),
                _zoomPanel(),
              ],
            ),
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: FloatingActionButton.large(
            backgroundColor: _green,
            onPressed: () => _showCaptureSheet(),
            child: const Icon(Icons.add, size: 34),
          ),
        ),
      ],
    );
  }

  Widget _landscapeLayout() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 322, child: _productPanel()),
                const SizedBox(width: 12),
                Expanded(child: _defectPanel()),
              ],
            ),
          ),
        ),
        _listHeader(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: _listExpanded ? 470 : 0,
          child: _listExpanded
              ? _listPanel(expanded: true)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _productPanel() {
    return _outlinedPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelTitle('Detalle del producto'),
          const SizedBox(height: 12),
          _cameraFrame(height: 166, large: false),
          const SizedBox(height: 16),
          _subPanel(
            title: 'Codigo de parte',
            expandChild: false,
            child: TextField(
              controller: _codigoController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _lookupModel(),
            ),
          ),
          const SizedBox(height: 12),
          _subPanel(
            title: 'Fecha',
            expandChild: false,
            child: _dateBox(compact: true),
          ),
        ],
      ),
    );
  }

  Widget _defectPanel() {
    return _outlinedPanel(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _panelTitle('Detalle del defecto'),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _subPanel(
                            title: 'Selecciona la linea',
                            child: _buttonGrid(
                              lineasDms,
                              _linea,
                              (value) => setState(() => _linea = value),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _subPanel(
                            title: 'Ubicacion',
                            child: TextFormField(
                              controller: _ubicacionController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              validator: _required,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _subPanel(
                            title: 'Defecto',
                            child: _defectDropdown(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _subPanel(
                            title: 'Area',
                            child: _buttonGrid(
                              areasDms,
                              _area,
                              (value) => setState(() => _area = value),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraFrame({required double height, required bool large}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: _line, width: 2),
        borderRadius: BorderRadius.circular(10),
        color: Colors.black,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (supportsCameraScanner)
            MobileScanner(controller: _scannerController, onDetect: _onDetect)
          else
            _manualScannerFallback(),
          Center(child: _scanCorners(size: large ? 256 : 132)),
          Positioned(
            top: large ? 16 : 12,
            right: large ? 16 : 12,
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: large
                    ? Colors.black.withValues(alpha: 0.7)
                    : const Color(0xFF2D9CE0),
                side: BorderSide(color: large ? Colors.white : _line),
              ),
              onPressed: supportsCameraScanner
                  ? _scannerController.switchCamera
                  : null,
              icon: const Icon(Icons.sync),
            ),
          ),
        ],
      ),
    );
  }

  Widget _manualScannerFallback() {
    return Container(
      color: const Color(0xFF171923),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.keyboard_alt_outlined, size: 46, color: _line),
          const SizedBox(height: 10),
          const Text(
            'Camara no disponible en Windows',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _codigoController,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'Escanea con lector USB o escribe el codigo',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) async {
              await _lookupModel();
              if (!mounted) return;
              if (MediaQuery.sizeOf(context).width < 820) {
                _showCaptureSheet();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _scanCorners({required double size}) {
    const length = 42.0;
    const stroke = 5.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          _corner(
            top: 0,
            left: 0,
            horizontal: true,
            length: length,
            stroke: stroke,
          ),
          _corner(
            top: 0,
            left: 0,
            horizontal: false,
            length: length,
            stroke: stroke,
          ),
          _corner(
            top: 0,
            right: 0,
            horizontal: true,
            length: length,
            stroke: stroke,
          ),
          _corner(
            top: 0,
            right: 0,
            horizontal: false,
            length: length,
            stroke: stroke,
          ),
          _corner(
            bottom: 0,
            left: 0,
            horizontal: true,
            length: length,
            stroke: stroke,
          ),
          _corner(
            bottom: 0,
            left: 0,
            horizontal: false,
            length: length,
            stroke: stroke,
          ),
          _corner(
            bottom: 0,
            right: 0,
            horizontal: true,
            length: length,
            stroke: stroke,
          ),
          _corner(
            bottom: 0,
            right: 0,
            horizontal: false,
            length: length,
            stroke: stroke,
          ),
        ],
      ),
    );
  }

  Widget _corner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required bool horizontal,
    required double length,
    required double stroke,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: horizontal ? length : stroke,
        height: horizontal ? stroke : length,
        color: Colors.white,
      ),
    );
  }

  Widget _zoomPanel() {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF424756),
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Zoom', style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                '${(1 + (_zoom * 2)).toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: _line,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _zoomButton(
                Icons.remove,
                () => _setZoom((_zoom - 0.1).clamp(0, 1)),
              ),
              Expanded(
                child: Slider(value: _zoom, onChanged: _setZoom),
              ),
              _zoomButton(Icons.add, () => _setZoom((_zoom + 0.1).clamp(0, 1))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onPressed) {
    return IconButton.outlined(
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        side: const BorderSide(color: _line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _listHeader() {
    return InkWell(
      onTap: () => setState(() => _listExpanded = !_listExpanded),
      child: Container(
        height: 68,
        color: _header,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Text(
              'Lista de defectos',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            IconButton.outlined(
              onPressed: () => setState(() => _listExpanded = !_listExpanded),
              icon: Icon(
                _listExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
              color: Colors.white,
              style: IconButton.styleFrom(side: const BorderSide(color: _line)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listPanel({required bool expanded}) {
    return Container(
      color: _header,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Column(
        children: [
          _filters(),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _defects.isEmpty
                ? const Center(
                    child: Text(
                      'No hay defectos para los filtros seleccionados',
                    ),
                  )
                : _desktopTable(),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _filterLabel('No. Parte'),
        SizedBox(
          width: 164,
          height: 36,
          child: TextField(
            controller: _codigoFiltroController,
            decoration: const InputDecoration(
              hintText: 'Buscar codigo...',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _load(),
          ),
        ),
        _filterLabel('Defecto'),
        SizedBox(
          width: 208,
          height: 36,
          child: _filterDropdown(_defectoFiltro, [
            null,
            ...defectosCatalogo,
          ], (v) => setState(() => _defectoFiltro = v)),
        ),
        _filterLabel('Linea'),
        SizedBox(
          width: 120,
          height: 36,
          child: _filterDropdown(_lineaFiltro, [
            null,
            ...lineasDms,
          ], (v) => setState(() => _lineaFiltro = v)),
        ),
        _filterLabel('Desde'),
        SizedBox(
          width: 130,
          height: 36,
          child: _dateFilter(_fechaInicio, (value) => _fechaInicio = value),
        ),
        _filterLabel('Hasta'),
        SizedBox(
          width: 130,
          height: 36,
          child: _dateFilter(_fechaFin, (value) => _fechaFin = value),
        ),
        SizedBox(
          width: 42,
          height: 42,
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: _line,
            ),
            onPressed: _load,
            child: const Icon(Icons.search),
          ),
        ),
        SizedBox(
          width: 42,
          height: 42,
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: _green,
            ),
            onPressed: () {},
            child: const Icon(Icons.download),
          ),
        ),
      ],
    );
  }

  Widget _filterLabel(String value) {
    return Text(
      value,
      style: const TextStyle(
        color: Color(0xFFB8C4CB),
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _filterDropdown(
    String? value,
    List<String?> options,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      key: ValueKey('filter-$value-${options.length}'),
      initialValue: value,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: options
          .map(
            (item) =>
                DropdownMenuItem(value: item, child: Text(item ?? 'Todos')),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _dateFilter(String value, ValueChanged<String> onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(value) ?? DateTime.now(),
          firstDate: DateTime(2024),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (picked == null) return;
        setState(() => onChanged(DateFormat('yyyy-MM-dd').format(picked)));
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        child: Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(value))),
      ),
    );
  }

  Widget _desktopTable() {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 42,
            columns: const [
              DataColumn(label: Text('Fecha')),
              DataColumn(label: Text('Linea')),
              DataColumn(label: Text('Codigo')),
              DataColumn(label: Text('Modelo')),
              DataColumn(label: Text('Defecto')),
              DataColumn(label: Text('Ubicacion')),
              DataColumn(label: Text('Area')),
              DataColumn(label: Text('Capturista')),
              DataColumn(label: Text('Hora')),
            ],
            rows: _defects
                .map(
                  (defect) => DataRow(
                    cells: [
                      DataCell(Text(formatDateOnly(defect.fecha))),
                      DataCell(Text(defect.linea)),
                      DataCell(
                        SizedBox(
                          width: 126,
                          child: Text(
                            defect.codigo,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(defect.modelo)),
                      DataCell(
                        SizedBox(
                          width: 130,
                          child: Text(
                            defect.defecto,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(defect.ubicacion)),
                      DataCell(Text(defect.area)),
                      DataCell(
                        SizedBox(
                          width: 130,
                          child: Text(
                            defect.registradoPor,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(formatTimeOnly(defect.fecha))),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _outlinedPanel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _subPanel({
    required String title,
    required Widget child,
    bool expandChild = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }

  Widget _panelTitle(String value) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buttonGrid(
    List<String> items,
    String? selected,
    ValueChanged<String> onChanged,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 4.5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      physics: const NeverScrollableScrollPhysics(),
      children: items
          .map(
            (item) => OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: item == selected
                    ? _green
                    : const Color(0xFF3F4554),
                side: const BorderSide(color: _line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              onPressed: () => onChanged(item),
              child: Text(
                item,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _defectDropdown() {
    return DropdownButtonFormField<String>(
      key: ValueKey('defect-$_defecto'),
      initialValue: _defecto,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        hintText: 'Selecciona un defecto',
      ),
      items: defectosCatalogo
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) => setState(() => _defecto = value),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Requerido' : null,
    );
  }

  Widget _dateBox({required bool compact}) {
    return InkWell(
      onTap: _pickCaptureDate,
      child: InputDecorator(
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
        child: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
      ),
    );
  }

  Widget _captureForm({required bool modal}) {
    return Form(
      key: modal ? _formKey : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (modal) _modalInfoBox(),
          const SizedBox(height: 16),
          const Text('Linea:', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _largeButtonGrid(
            lineasDms,
            _linea,
            (value) => setState(() => _linea = value),
          ),
          const SizedBox(height: 18),
          const Text('Defecto:', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _defectDropdown(),
          const SizedBox(height: 18),
          TextFormField(
            controller: _ubicacionController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Ubicacion del defecto',
              border: OutlineInputBorder(),
            ),
            validator: _required,
          ),
          const SizedBox(height: 18),
          const Text('Area:', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _largeButtonGrid(
            areasDms,
            _area,
            (value) => setState(() => _area = value),
          ),
        ],
      ),
    );
  }

  Widget _modalInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Fecha:',
                style: TextStyle(
                  color: Color(0xFFB8C4CB),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('dd/MM/yyyy').format(_fecha),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const Divider(color: _line),
          Row(
            children: [
              const Text(
                'Codigo de parte:',
                style: TextStyle(
                  color: Color(0xFFB8C4CB),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  _codigoController.text,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _largeButtonGrid(
    List<String> items,
    String? selected,
    ValueChanged<String> onChanged,
  ) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 5.2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      physics: const NeverScrollableScrollPhysics(),
      children: items
          .map(
            (item) => OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                backgroundColor: item == selected
                    ? _green
                    : const Color(0xFF30313E),
                side: const BorderSide(color: _line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              onPressed: () => onChanged(item),
              child: Text(
                item,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _showCaptureSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.65,
              maxChildSize: 0.96,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF424551),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    border: Border(top: BorderSide(color: _line)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 70,
                        decoration: const BoxDecoration(
                          color: _header,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          border: Border(
                            bottom: BorderSide(color: _green, width: 2),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Row(
                          children: [
                            const Text(
                              'Capturar Defecto',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, size: 30),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                          child: _captureForm(modal: true),
                        ),
                      ),
                      Container(
                        height: 90,
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFF414450),
                          border: Border(top: BorderSide(color: _line)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  _clearForm();
                                  setModalState(() {});
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Limpiar'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 56),
                                  side: const BorderSide(color: _line),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () async {
                                        final ok = await _saveDefect(
                                          closeModal: true,
                                        );
                                        if (ok && context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      },
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Guardar'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 56),
                                  backgroundColor: _green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Requerido' : null;
  }

  Future<void> _pickCaptureDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final defects = await widget.appState.api.getDefects(
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        linea: _lineaFiltro,
        codigo: _codigoFiltroController.text.trim(),
        defecto: _defectoFiltro,
      );
      if (mounted) setState(() => _defects = defects);
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

  Future<bool> _saveDefect({bool closeModal = false}) async {
    final valid = _formKey.currentState?.validate() ?? true;
    if (!valid ||
        _linea == null ||
        _defecto == null ||
        _area == null ||
        _codigoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        snack('Completa todos los campos requeridos', error: true),
      );
      return false;
    }
    final user = widget.appState.user!;
    final etapa = user.etapaDeteccion;
    if (etapa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        snack('Este rol no tiene etapa de deteccion', error: true),
      );
      return false;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final fechaRegistro = DateTime(
        _fecha.year,
        _fecha.month,
        _fecha.day,
        now.hour,
        now.minute,
        now.second,
      );
      await widget.appState.api.createDefect({
        'fecha': mysqlDateTime(fechaRegistro),
        'linea': _linea,
        'codigo': _codigoController.text.trim().toUpperCase(),
        'defecto': _defecto,
        'ubicacion': _ubicacionController.text.trim().toUpperCase(),
        'area': _area,
        'modelo': _modeloController.text.trim(),
        'tipo_inspeccion': _tipoInspeccion,
        'etapa_deteccion': etapa,
        'registrado_por': user.displayName,
      });
      _clearForm();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack('Defecto capturado correctamente'));
      }
      return true;
    } on DmsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack(error.message, error: true));
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearForm() {
    _codigoController.clear();
    _ubicacionController.clear();
    _modeloController.clear();
    setState(() {
      _linea = null;
      _defecto = null;
      _area = null;
      _tipoInspeccion = 'Visual';
      _fecha = DateTime.now();
    });
  }

  Future<void> _lookupModel() async {
    final codigo = _codigoController.text.trim().toUpperCase();
    if (codigo.length < 3) return;
    try {
      final modelo = await widget.appState.api.getModelo(codigo);
      if (mounted) setState(() => _modeloController.text = modelo);
    } on DmsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(snack(error.message, error: true));
      }
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanLocked) return;
    final code = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .firstOrNull;
    if (code == null) return;
    _scanLocked = true;
    setState(() => _codigoController.text = code.trim().toUpperCase());
    await _lookupModel();
    if (mounted && MediaQuery.sizeOf(context).width < 820) {
      await _showCaptureSheet();
    }
    Future.delayed(const Duration(seconds: 2), () => _scanLocked = false);
  }

  Future<void> _setZoom(double value) async {
    setState(() => _zoom = value);
    if (supportsCameraScanner) {
      await _scannerController.setZoomScale(value);
    }
  }
}
