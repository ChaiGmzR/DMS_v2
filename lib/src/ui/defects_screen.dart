import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_constants.dart';
import '../core/code_parser.dart';
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
  static const _scanPrompt = 'Apunta la camara al QR o codigo';
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
  final _desktopTableHorizontalController = ScrollController();
  final _desktopTableVerticalController = ScrollController();
  late final MobileScannerController _scannerController;

  List<DefectItem> _defects = [];
  bool _loading = false;
  bool _saving = false;
  bool _exporting = false;
  bool _listExpanded = false;
  bool _scanLocked = false;
  String _scanStatus = _scanPrompt;
  String? _ignoredScanCode;
  Timer? _ignoredScanTimer;
  Timer? _scanUnlockTimer;

  DateTime _fecha = DateTime.now();
  String? _linea;
  String? _defecto;
  String? _area;
  String _tipoInspeccion = 'Visual';
  String _fechaInicio = todayIso();
  String _fechaFin = todayIso();
  String? _lineaFiltro;
  String? _defectoFiltro;
  int _defectsPage = 1;
  int _defectsPageSize = 100;
  int _defectsTotal = 0;
  double _zoom = 0;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      autoZoom: true,
      detectionSpeed: DetectionSpeed.unrestricted,
      formats: const [BarcodeFormat.all],
    );
    _load();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _ubicacionController.dispose();
    _modeloController.dispose();
    _codigoFiltroController.dispose();
    _desktopTableHorizontalController.dispose();
    _desktopTableVerticalController.dispose();
    _ignoredScanTimer?.cancel();
    _scanUnlockTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final phone = width < 600;
    final portrait = width < 820;
    final desktop = !supportsCameraScanner && width >= 900;
    final body = desktop
        ? _desktopLayout()
        : portrait
        ? _portraitLayout(phone: phone)
        : _landscapeLayout();

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
    final desktop =
        !supportsCameraScanner && MediaQuery.sizeOf(context).width >= 900;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _line, width: 2)),
      ),
      child: SizedBox(
        height: desktop
            ? 80
            : portrait
            ? 68
            : 60,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: desktop
                ? 8
                : portrait
                ? 18
                : 16,
          ),
          child: Row(
            children: [
              SizedBox(
                width: desktop
                    ? 62
                    : portrait
                    ? 44
                    : 42,
                height: desktop
                    ? 62
                    : portrait
                    ? 44
                    : 42,
                child: Image.asset(AppConstants.logoAsset, fit: BoxFit.contain),
              ),
              SizedBox(width: desktop ? 10 : 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DMS',
                    style: TextStyle(
                      fontSize: desktop
                          ? 36
                          : portrait
                          ? 20
                          : 22,
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
              if (!portrait && !desktop) ...[
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
              _userActionButton(desktop: desktop),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userActionButton({required bool desktop}) {
    if (!desktop) {
      return IconButton.filled(
        tooltip: 'Cerrar sesion',
        onPressed: widget.appState.logout,
        icon: const Icon(Icons.logout),
        color: Colors.white,
        style: IconButton.styleFrom(
          side: const BorderSide(color: _line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }

    final user = widget.appState.user;
    return PopupMenuButton<_UserMenuAction>(
      tooltip: 'Usuario',
      offset: const Offset(0, 54),
      onSelected: (action) {
        if (action == _UserMenuAction.logout) widget.appState.logout();
      },
      itemBuilder: (context) => [
        PopupMenuItem<_UserMenuAction>(
          enabled: false,
          child: SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Usuario',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                _userInfoLine('Usuario', user?.username ?? '-'),
                _userInfoLine('Rol', _roleLabel(user?.rol ?? '-')),
                _userInfoLine('Area', user?.area ?? '-'),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_UserMenuAction>(
          value: _UserMenuAction.logout,
          child: Row(
            children: [
              Icon(Icons.logout),
              SizedBox(width: 10),
              Text('Cerrar sesion'),
            ],
          ),
        ),
      ],
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
        child: const Icon(Icons.person, color: Colors.white),
      ),
    );
  }

  Widget _userInfoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFB8C4CB),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _portraitLayout({required bool phone}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = phone ? 12.0 : 40.0;
        final frameWidth = constraints.maxWidth - (horizontalPadding * 2);
        final cameraHeight = phone
            ? (frameWidth * 1.08).clamp(260.0, 430.0)
            : (constraints.maxHeight * 0.58).clamp(360.0, 445.0);
        final cornerSize = phone
            ? (frameWidth * 0.58).clamp(150.0, 220.0)
            : 256.0;

        return Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
                  phone ? 108 : 128,
                ),
                child: Column(
                  children: [
                    _cameraFrame(
                      height: cameraHeight,
                      large: true,
                      cornerSize: cornerSize,
                    ),
                    SizedBox(height: phone ? 18 : 86),
                    _zoomPanel(),
                  ],
                ),
              ),
            ),
            Positioned(
              right: phone ? 16 : 24,
              bottom: phone ? 16 : 24,
              child: FloatingActionButton.large(
                backgroundColor: _green,
                onPressed: () => _showCaptureSheet(),
                child: const Icon(Icons.add, size: 34),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _desktopLayout() {
    return Row(
      children: [
        SizedBox(width: 345, child: _desktopCapturePane()),
        const VerticalDivider(width: 1, color: _line),
        Expanded(child: _desktopListPane()),
      ],
    );
  }

  Widget _desktopCapturePane() {
    return Container(
      color: const Color(0xFF414553),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 44,
              color: _header,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: const Text(
                'Detalle del producto',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 14, 14, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _desktopLabel('Fecha:'),
                    _dateBox(compact: true),
                    const SizedBox(height: 10),
                    _desktopLabel('Linea:'),
                    _desktopDropdown(
                      value: _linea,
                      hint: 'Seleccione linea',
                      options: lineasDms,
                      onChanged: (value) => setState(() => _linea = value),
                      validator: (value) => value == null ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 10),
                    _desktopLabel('Codigo de parte:'),
                    TextFormField(
                      controller: _codigoController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Escanear o escribir',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: _required,
                      onFieldSubmitted: (_) {
                        _normalizeCurrentCode();
                        _lookupModel();
                      },
                    ),
                    const SizedBox(height: 10),
                    _desktopLabel('Defecto:'),
                    _desktopDropdown(
                      value: _defecto,
                      hint: 'Selecciona un defecto',
                      options: defectosCatalogo,
                      onChanged: (value) => setState(() => _defecto = value),
                      validator: (value) => value == null ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 10),
                    _desktopLabel('Ubicacion:'),
                    TextFormField(
                      controller: _ubicacionController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Ubicacion del defecto',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 10),
                    _desktopLabel('Area:'),
                    _desktopDropdown(
                      value: _area,
                      hint: 'Seleccione area',
                      options: areasDms,
                      onChanged: (value) => setState(() => _area = value),
                      validator: (value) => value == null ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 59),
                        backgroundColor: _green,
                      ),
                      onPressed:
                          widget.appState.user?.canCapture == true && !_saving
                          ? _saveDefect
                          : null,
                      icon: const Icon(Icons.save_alt),
                      label: const Text(
                        'Capturar (F1)',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        side: const BorderSide(color: _line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed:
                          widget.appState.user?.canCapture == true && !_saving
                          ? _showBatchCaptureDialog
                          : null,
                      icon: const Icon(Icons.playlist_add_check),
                      label: const Text(
                        'Captura multiple',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopListPane() {
    return Container(
      color: _bg,
      child: Column(
        children: [
          Container(
            height: 44,
            color: _header,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: const Text(
              'Lista de defectos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          Container(
            width: double.infinity,
            color: const Color(0xFF424452),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: _filters(desktop: true),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _defects.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 38,
                          color: Color(0xFF59606C),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'No hay defectos registrados',
                          style: TextStyle(
                            color: Color(0xFFB8C4CB),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  )
                : _desktopTable(fillWidth: true),
          ),
          if (_defectsTotal > 0) _paginationBar(),
        ],
      ),
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
              onSubmitted: (_) {
                _normalizeCurrentCode();
                _lookupModel();
              },
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

  Widget _cameraFrame({
    required double height,
    required bool large,
    double? cornerSize,
  }) {
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
            MobileScanner(
              controller: _scannerController,
              fit: BoxFit.cover,
              tapToFocus: true,
              onDetect: _onDetect,
              onDetectError: (error, _) =>
                  _setScanStatus('Error al decodificar: ${error.toString()}'),
              placeholderBuilder: (_) => _scannerMessage('Iniciando camara...'),
              errorBuilder: (_, error) => _scannerMessage(
                'Camara no disponible: ${error.errorCode.message}',
              ),
            )
          else
            _manualScannerFallback(),
          Center(child: _scanCorners(size: cornerSize ?? (large ? 256 : 132))),
          if (supportsCameraScanner)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: _scanStatusBadge(),
            ),
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
              _normalizeCurrentCode();
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Container(
        width: double.infinity,
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
                const Text(
                  'Zoom',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
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
                _zoomButton(
                  Icons.add,
                  () => _setZoom((_zoom + 0.1).clamp(0, 1)),
                ),
              ],
            ),
          ],
        ),
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

  Widget _filters({bool desktop = false}) {
    if (desktop) return _desktopFilters();

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
            onSubmitted: (_) => _applyFilters(),
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
            onPressed: _applyFilters,
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

  Widget _desktopFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const fieldCount = 5;
        const groupGap = 12.0;
        const labelGap = 8.0;
        const actionWidth = 96.0;
        const labelWidths = [78.0, 58.0, 48.0, 54.0, 54.0];
        const minFieldWidth = 112.0;
        final fixedWidth =
            actionWidth +
            (groupGap * fieldCount) +
            (labelGap * fieldCount) +
            labelWidths.fold<double>(0, (total, width) => total + width);
        final fieldWidth = math.max(
          minFieldWidth,
          (constraints.maxWidth - fixedWidth) / fieldCount,
        );
        final rowWidth = fixedWidth + (fieldWidth * fieldCount);
        final actions = _filterActions();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(constraints.maxWidth, rowWidth),
            child: Row(
              children: [
                _desktopFilterField(
                  label: 'No. Parte',
                  labelWidth: labelWidths[0],
                  fieldWidth: fieldWidth,
                  child: _codeFilterField(),
                ),
                const SizedBox(width: groupGap),
                _desktopFilterField(
                  label: 'Defecto',
                  labelWidth: labelWidths[1],
                  fieldWidth: fieldWidth,
                  child: _defectFilterDropdown(),
                ),
                const SizedBox(width: groupGap),
                _desktopFilterField(
                  label: 'Linea',
                  labelWidth: labelWidths[2],
                  fieldWidth: fieldWidth,
                  child: _lineFilterDropdown(),
                ),
                const SizedBox(width: groupGap),
                _desktopFilterField(
                  label: 'Desde',
                  labelWidth: labelWidths[3],
                  fieldWidth: fieldWidth,
                  child: _dateFilter(
                    _fechaInicio,
                    (value) => _fechaInicio = value,
                  ),
                ),
                const SizedBox(width: groupGap),
                _desktopFilterField(
                  label: 'Hasta',
                  labelWidth: labelWidths[4],
                  fieldWidth: fieldWidth,
                  child: _dateFilter(_fechaFin, (value) => _fechaFin = value),
                ),
                const SizedBox(width: groupGap),
                actions,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _desktopFilterField({
    required String label,
    required double labelWidth,
    required double fieldWidth,
    required Widget child,
  }) {
    return Row(
      children: [
        SizedBox(width: labelWidth, child: _filterLabel(label)),
        const SizedBox(width: 8),
        SizedBox(width: fieldWidth, height: 36, child: child),
      ],
    );
  }

  Widget _filterActions() {
    return SizedBox(
      width: 96,
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: _line,
              ),
              onPressed: _applyFilters,
              child: const Icon(Icons.search),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 42,
            height: 42,
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: _green,
              ),
              onPressed: _defects.isEmpty || _exporting
                  ? null
                  : _exportDefectsToExcel,
              child: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paginationBar() {
    final pageCount = math.max(1, (_defectsTotal / _defectsPageSize).ceil());
    final currentPage = _defectsPage.clamp(1, pageCount);
    final start = _defectsTotal == 0
        ? 0
        : ((currentPage - 1) * _defectsPageSize) + 1;
    final end = math.min(currentPage * _defectsPageSize, _defectsTotal);

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF424452),
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Text(
            '$start-$end de $_defectsTotal',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 18),
          const Text(
            'Filas',
            style: TextStyle(
              color: Color(0xFFB8C4CB),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            height: 36,
            child: DropdownButtonFormField<int>(
              initialValue: _defectsPageSize,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
              items: const [50, 100, 200, 500]
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text('$value')),
                  )
                  .toList(),
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _defectsPageSize = value;
                        _defectsPage = 1;
                      });
                      _load();
                    },
            ),
          ),
          const Spacer(),
          Text(
            'Pagina $currentPage de $pageCount',
            style: const TextStyle(
              color: Color(0xFFB8C4CB),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          IconButton.outlined(
            tooltip: 'Primera pagina',
            onPressed: _loading || currentPage <= 1
                ? null
                : () => _goToDefectsPage(1),
            icon: const Icon(Icons.first_page),
          ),
          const SizedBox(width: 6),
          IconButton.outlined(
            tooltip: 'Pagina anterior',
            onPressed: _loading || currentPage <= 1
                ? null
                : () => _goToDefectsPage(currentPage - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 6),
          IconButton.outlined(
            tooltip: 'Pagina siguiente',
            onPressed: _loading || currentPage >= pageCount
                ? null
                : () => _goToDefectsPage(currentPage + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 6),
          IconButton.outlined(
            tooltip: 'Ultima pagina',
            onPressed: _loading || currentPage >= pageCount
                ? null
                : () => _goToDefectsPage(pageCount),
            icon: const Icon(Icons.last_page),
          ),
        ],
      ),
    );
  }

  Widget _codeFilterField() {
    return TextField(
      controller: _codigoFiltroController,
      decoration: const InputDecoration(
        hintText: 'Buscar codigo...',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onSubmitted: (_) => _applyFilters(),
    );
  }

  Widget _defectFilterDropdown() {
    return _filterDropdown(_defectoFiltro, [
      null,
      ...defectosCatalogo,
    ], (v) => setState(() => _defectoFiltro = v));
  }

  Widget _lineFilterDropdown() {
    return _filterDropdown(_lineaFiltro, [
      null,
      ...lineasDms,
    ], (v) => setState(() => _lineaFiltro = v));
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

  Widget _desktopTable({bool fillWidth = false}) {
    if (fillWidth) return _responsiveDesktopTable();

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
              DataColumn(label: Text('Departamento')),
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
                      DataCell(Text(_departmentLabel(defect.etapaDeteccion))),
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

  Widget _responsiveDesktopTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _defectTableColumns();
        final minWidth = columns.fold<double>(
          0,
          (total, column) => total + column.minWidth,
        );
        final tableWidth = math.max(constraints.maxWidth, minWidth);
        final widths = _tableColumnWidths(columns, tableWidth);

        return Scrollbar(
          controller: _desktopTableVerticalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _desktopTableVerticalController,
            child: Scrollbar(
              controller: _desktopTableHorizontalController,
              thumbVisibility: tableWidth > constraints.maxWidth,
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: _desktopTableHorizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      _desktopTableHeader(columns, widths),
                      for (final defect in _defects)
                        _desktopTableRow(defect, columns, widths),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _desktopTableHeader(
    List<_DefectTableColumn> columns,
    List<double> widths,
  ) {
    return Container(
      height: 44,
      color: _green,
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            SizedBox(
              width: widths[i],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: columns[i].alignment,
                  child: Text(
                    columns[i].label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _desktopTableRow(
    DefectItem defect,
    List<_DefectTableColumn> columns,
    List<double> widths,
  ) {
    final values = [
      formatDateOnly(defect.fecha),
      defect.linea,
      defect.codigo,
      defect.modelo,
      defect.defecto,
      defect.ubicacion,
      defect.area,
      _departmentLabel(defect.etapaDeteccion),
      defect.registradoPor,
      formatTimeOnly(defect.fecha),
    ];

    return Container(
      height: 42,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF414735))),
      ),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            SizedBox(
              width: widths[i],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: columns[i].alignment,
                  child: Text(
                    values[i],
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<double> _tableColumnWidths(
    List<_DefectTableColumn> columns,
    double tableWidth,
  ) {
    final minWidth = columns.fold<double>(
      0,
      (total, column) => total + column.minWidth,
    );
    final extraWidth = math.max(0, tableWidth - minWidth);
    final totalFlex = columns.fold<double>(
      0,
      (total, column) => total + column.flex,
    );

    return [
      for (final column in columns)
        column.minWidth + (extraWidth * (column.flex / totalFlex)),
    ];
  }

  List<_DefectTableColumn> _defectTableColumns() {
    return const [
      _DefectTableColumn('Fecha', 106, 0.8),
      _DefectTableColumn('Linea', 72, 0.4, alignment: Alignment.center),
      _DefectTableColumn('Codigo', 170, 1.4),
      _DefectTableColumn('Modelo', 126, 1.0),
      _DefectTableColumn('Defecto', 152, 1.2),
      _DefectTableColumn('Ubicacion', 126, 1.0),
      _DefectTableColumn('Area', 142, 1.1),
      _DefectTableColumn('Departamento', 136, 0.9),
      _DefectTableColumn('Capturista', 172, 1.4),
      _DefectTableColumn('Hora', 76, 0.4, alignment: Alignment.center),
    ];
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

  Widget _desktopLabel(String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _desktopDropdown({
    required String? value,
    required String hint,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey('desktop-$hint-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator,
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

  Widget _captureFormForModal(StateSetter setModalState) {
    void selectLine(String value) {
      setState(() => _linea = value);
      setModalState(() {});
    }

    void selectArea(String value) {
      setState(() => _area = value);
      setModalState(() {});
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _modalInfoBox(),
          const SizedBox(height: 16),
          const Text('Linea:', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _largeButtonGrid(lineasDms, _linea, selectLine),
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
          _largeButtonGrid(areasDms, _area, selectArea),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = constraints.maxWidth < 360;
        return GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          childAspectRatio: phone ? 3.1 : 4.6,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          physics: const NeverScrollableScrollPhysics(),
          children: items
              .map(
                (item) => OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
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
      },
    );
  }

  Future<void> _showCaptureSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomSafeArea = MediaQuery.viewPaddingOf(context).bottom;
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
                          padding: EdgeInsets.fromLTRB(
                            20,
                            18,
                            20,
                            112 + bottomSafeArea,
                          ),
                          child: _captureFormForModal(setModalState),
                        ),
                      ),
                      Container(
                        height: 90 + bottomSafeArea,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          16 + bottomSafeArea,
                        ),
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

  String _roleLabel(String role) {
    return switch (role) {
      'Inspector_LQC' => 'Inspector LQC',
      'Inspector_OQC' => 'Inspector OQC',
      'Supervisor_Calidad' => 'Supervisor Calidad',
      'Supervisor_Produccion' => 'Supervisor Produccion',
      'Reparador' => 'Reparador',
      'Admin' => 'Admin',
      _ => role,
    };
  }

  String _departmentLabel(String value) {
    final department = value.trim();
    return department.isEmpty ? '-' : department;
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

  Future<void> _exportDefectsToExcel() async {
    if (_defects.isEmpty || _exporting) return;

    setState(() => _exporting = true);
    try {
      final exportDefects = await widget.appState.api.getDefects(
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        linea: _lineaFiltro,
        codigo: _codigoFiltroController.text.trim(),
        defecto: _defectoFiltro,
        limit: 0,
      );

      final workbook = xls.Excel.createExcel();
      const sheetName = 'Defectos';
      final sheet = workbook[sheetName];
      final defaultSheet = workbook.getDefaultSheet();
      if (defaultSheet != null && defaultSheet != sheetName) {
        workbook.delete(defaultSheet);
      }

      sheet.appendRow([
        _excelText('Fecha'),
        _excelText('Linea'),
        _excelText('Codigo'),
        _excelText('Modelo'),
        _excelText('Defecto'),
        _excelText('Ubicacion'),
        _excelText('Area'),
        _excelText('Departamento'),
        _excelText('Capturista'),
        _excelText('Hora'),
        _excelText('Status'),
      ]);

      for (final defect in exportDefects) {
        sheet.appendRow([
          _excelText(formatDateOnly(defect.fecha)),
          _excelText(defect.linea),
          _excelText(defect.codigo),
          _excelText(defect.modelo),
          _excelText(defect.defecto),
          _excelText(defect.ubicacion),
          _excelText(defect.area),
          _excelText(_departmentLabel(defect.etapaDeteccion)),
          _excelText(defect.registradoPor),
          _excelText(formatTimeOnly(defect.fecha)),
          _excelText(statusLabel(defect.status)),
        ]);
      }

      const widths = [
        14.0,
        10.0,
        24.0,
        18.0,
        20.0,
        18.0,
        18.0,
        18.0,
        28.0,
        10.0,
        18.0,
      ];
      for (var index = 0; index < widths.length; index++) {
        sheet.setColumnWidth(index, widths[index]);
      }

      final fileName = _excelFileName();
      final bytes = workbook.save(fileName: fileName);
      if (bytes == null || bytes.isEmpty) {
        throw const FileSystemException('No se generaron datos de Excel');
      }

      final directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(
        file.path,
        type:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (!mounted) return;
      final opened = result.type == ResultType.done;
      ScaffoldMessenger.of(context).showSnackBar(
        snack(
          opened
              ? 'Excel descargado en ${file.path}'
              : 'Excel guardado en ${file.path}',
          error: false,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        snack('No se pudo generar el archivo de Excel', error: true),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  xls.TextCellValue _excelText(String value) => xls.TextCellValue(value);

  String _excelFileName() {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'DMS_defectos_$timestamp.xlsx';
  }

  void _applyFilters() {
    setState(() => _defectsPage = 1);
    _load();
  }

  void _goToDefectsPage(int page) {
    setState(() => _defectsPage = page);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final page = await widget.appState.api.getDefectsPage(
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        linea: _lineaFiltro,
        codigo: _codigoFiltroController.text.trim(),
        defecto: _defectoFiltro,
        page: _defectsPage,
        pageSize: _defectsPageSize,
      );
      if (mounted) {
        setState(() {
          _defects = page.items;
          _defectsTotal = page.total;
          _defectsPage = page.page;
          _defectsPageSize = page.pageSize;
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

  Future<void> _showBatchCaptureDialog() async {
    final registeredCount = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BatchDefectDialog(
        appState: widget.appState,
        initialDate: _fecha,
        initialLine: _linea,
        initialDefect: _defecto,
        initialLocation: _ubicacionController.text,
        initialArea: _area,
        initialInspectionType: _tipoInspeccion,
      ),
    );

    if (registeredCount == null || registeredCount == 0) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      snack(
        registeredCount == 1
            ? '1 pieza registrada correctamente'
            : '$registeredCount piezas registradas correctamente',
      ),
    );
  }

  Future<bool> _saveDefect({bool closeModal = false}) async {
    _normalizeCurrentCode();
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
      final registeredCode = _codigoController.text.trim().toUpperCase();
      _ignoreScanCodeUntilRemoved(registeredCode);
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
      _scanStatus = _scanPrompt;
    });
  }

  Future<void> _lookupModel() async {
    _normalizeCurrentCode();
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
    final rawCode = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .firstOrNull;
    final code = rawCode == null ? null : extractPartCode(rawCode);
    if (code == null) {
      _scanLocked = true;
      _setScanStatus('QR detectado sin codigo valido: ${_shortScan(rawCode)}');
      _unlockScannerAfter(const Duration(milliseconds: 900));
      return;
    }

    final normalizedCode = code.trim().toUpperCase();
    if (_isIgnoredScanCode(normalizedCode)) return;

    _scanLocked = true;
    _setScanStatus('Codigo detectado: $normalizedCode');
    setState(() => _codigoController.text = normalizedCode);
    unawaited(_lookupModel());
    try {
      if (mounted && MediaQuery.sizeOf(context).width < 820) {
        await _showCaptureSheet();
      }
    } finally {
      _unlockScannerAfter(const Duration(seconds: 1));
    }
  }

  Future<void> _setZoom(double value) async {
    setState(() => _zoom = value);
    if (supportsCameraScanner) {
      await _scannerController.setZoomScale(value);
    }
  }

  void _normalizeCurrentCode() {
    final code = extractPartCode(_codigoController.text);
    if (code == null) return;
    final upper = code.toUpperCase();
    if (_codigoController.text == upper) return;
    _codigoController.value = TextEditingValue(
      text: upper,
      selection: TextSelection.collapsed(offset: upper.length),
    );
  }

  void _setScanStatus(String value) {
    if (!mounted) return;
    setState(() => _scanStatus = value);
  }

  bool _isIgnoredScanCode(String code) {
    if (_ignoredScanCode != code) return false;
    _extendIgnoredScanWindow();
    return true;
  }

  void _ignoreScanCodeUntilRemoved(String code) {
    if (code.isEmpty) return;
    _ignoredScanCode = code;
    _extendIgnoredScanWindow();
  }

  void _extendIgnoredScanWindow() {
    _ignoredScanTimer?.cancel();
    _ignoredScanTimer = Timer(const Duration(milliseconds: 1500), () {
      _ignoredScanCode = null;
    });
  }

  void _unlockScannerAfter(Duration duration) {
    _scanUnlockTimer?.cancel();
    _scanUnlockTimer = Timer(duration, () {
      _scanLocked = false;
    });
  }

  String _shortScan(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'sin datos';
    return text.length <= 42 ? text : '${text.substring(0, 42)}...';
  }

  Widget _scanStatusBadge() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          _scanStatus,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _scannerMessage(String value) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _BatchDefectDialog extends StatefulWidget {
  const _BatchDefectDialog({
    required this.appState,
    required this.initialDate,
    required this.initialLine,
    required this.initialDefect,
    required this.initialLocation,
    required this.initialArea,
    required this.initialInspectionType,
  });

  final AppState appState;
  final DateTime initialDate;
  final String? initialLine;
  final String? initialDefect;
  final String initialLocation;
  final String? initialArea;
  final String initialInspectionType;

  @override
  State<_BatchDefectDialog> createState() => _BatchDefectDialogState();
}

class _BatchDefectDialogState extends State<_BatchDefectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  final _ubicacionController = TextEditingController();
  final _codigoFocusNode = FocusNode();
  final List<_BatchCartItem> _cart = [];

  late DateTime _fecha;
  late String _tipoInspeccion;
  String? _linea;
  String? _defecto;
  String? _area;
  bool _adding = false;
  bool _saving = false;
  int _registeredCount = 0;

  @override
  void initState() {
    super.initState();
    _fecha = widget.initialDate;
    _linea = widget.initialLine;
    _defecto = widget.initialDefect;
    _area = widget.initialArea;
    _tipoInspeccion = widget.initialInspectionType;
    _ubicacionController.text = widget.initialLocation.trim().toUpperCase();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _ubicacionController.dispose();
    _codigoFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 720),
        child: Column(
          children: [
            _header(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 360, child: _sharedForm()),
                    const SizedBox(width: 16),
                    Expanded(child: _cartPanel()),
                  ],
                ),
              ),
            ),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 58,
      color: _DefectsScreenState._header,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          const Icon(Icons.playlist_add_check),
          const SizedBox(width: 10),
          const Text(
            'Captura multiple',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          Text(
            'Total: ${_cart.length}',
            style: const TextStyle(
              color: Color(0xFFB9D6DA),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: _saving ? null : _close,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _sharedForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _modalLabel('Fecha'),
            InkWell(
              onTap: _saving ? null : _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
              ),
            ),
            const SizedBox(height: 10),
            _modalLabel('Usuario'),
            InputDecorator(
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              child: Text(widget.appState.user?.displayName ?? '-'),
            ),
            const SizedBox(height: 10),
            _modalLabel('Linea'),
            _modalDropdown(
              value: _linea,
              hint: 'Seleccione linea',
              options: lineasDms,
              onChanged: (value) => setState(() => _linea = value),
            ),
            const SizedBox(height: 10),
            _modalLabel('Defecto'),
            _modalDropdown(
              value: _defecto,
              hint: 'Selecciona un defecto',
              options: defectosCatalogo,
              onChanged: (value) => setState(() => _defecto = value),
            ),
            const SizedBox(height: 10),
            _modalLabel('Ubicacion / componente'),
            TextFormField(
              controller: _ubicacionController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Ubicacion del defecto',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              validator: _required,
              onChanged: (value) {
                final upper = value.toUpperCase();
                if (value == upper) return;
                _ubicacionController.value = TextEditingValue(
                  text: upper,
                  selection: TextSelection.collapsed(offset: upper.length),
                );
              },
            ),
            const SizedBox(height: 10),
            _modalLabel('Area'),
            _modalDropdown(
              value: _area,
              hint: 'Seleccione area',
              options: areasDms,
              onChanged: (value) => setState(() => _area = value),
            ),
            const SizedBox(height: 14),
            _modalLabel('Codigo de pieza'),
            TextFormField(
              controller: _codigoController,
              focusNode: _codigoFocusNode,
              enabled: !_saving,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Escanear o escribir',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onFieldSubmitted: (_) => _addCodeToCart(),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: _DefectsScreenState._green,
              ),
              onPressed: _adding || _saving ? null : _addCodeToCart,
              icon: _adding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_shopping_cart),
              label: const Text(
                'Agregar al carrito',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartPanel() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _DefectsScreenState._line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF424452),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Text(
                  'Carrito de piezas',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  '${_cart.length} piezas',
                  style: const TextStyle(
                    color: Color(0xFFB8C4CB),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Text(
                      'Agrega piezas para confirmar el registro',
                      style: TextStyle(
                        color: Color(0xFFB8C4CB),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: _cart.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 15,
                          backgroundColor: _DefectsScreenState._green,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(
                          item.codigo,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          item.modelo.trim().isEmpty
                              ? 'Sin modelo'
                              : item.modelo,
                        ),
                        trailing: IconButton(
                          tooltip: 'Quitar',
                          onPressed: _saving
                              ? null
                              : () => setState(() => _cart.removeAt(index)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF2F3340),
        border: Border(top: BorderSide(color: _DefectsScreenState._line)),
      ),
      child: Row(
        children: [
          Text(
            _registeredCount == 0
                ? '${_cart.length} pendientes'
                : 'Registradas: $_registeredCount | pendientes: ${_cart.length}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _saving ? null : _close,
            icon: const Icon(Icons.close),
            label: const Text('Cancelar'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(180, 48),
              backgroundColor: _DefectsScreenState._green,
            ),
            onPressed: _saving || _cart.isEmpty ? null : _confirmBatch,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text(
              'Confirmar registro',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modalLabel(String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _modalDropdown({
    required String? value,
    required String hint,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _saving ? null : onChanged,
      validator: (value) => value == null ? 'Requerido' : null,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _addCodeToCart() async {
    if (_adding || _saving) return;

    final valid = _formKey.currentState?.validate() ?? true;
    if (!valid) return;

    final codigo = _normalizeCode(_codigoController.text);
    if (codigo.isEmpty) {
      _showSnack('Captura un codigo de pieza', error: true);
      return;
    }
    if (_cart.any((item) => item.codigo == codigo)) {
      _showSnack('El codigo ya esta en el carrito', error: true);
      _codigoController.clear();
      _codigoFocusNode.requestFocus();
      return;
    }

    setState(() => _adding = true);
    var modelo = '';
    try {
      if (codigo.length >= 3) {
        modelo = await widget.appState.api.getModelo(codigo);
      }
    } on DmsException catch (error) {
      _showSnack(error.message, error: true);
    } finally {
      if (mounted) setState(() => _adding = false);
    }

    if (!mounted) return;
    setState(() {
      _cart.add(_BatchCartItem(codigo: codigo, modelo: modelo));
      _codigoController.clear();
    });
    _codigoFocusNode.requestFocus();
  }

  Future<void> _confirmBatch() async {
    final valid = _formKey.currentState?.validate() ?? true;
    if (!valid) return;

    final user = widget.appState.user;
    if (user == null || !user.canCapture) {
      _showSnack('Este usuario no puede capturar defectos', error: true);
      return;
    }
    final etapa = user.etapaDeteccion;
    if (etapa.isEmpty) {
      _showSnack('Este rol no tiene etapa de deteccion', error: true);
      return;
    }
    if (_cart.isEmpty) {
      _showSnack('Agrega al menos una pieza al carrito', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      for (final item in List<_BatchCartItem>.from(_cart)) {
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
          'codigo': item.codigo,
          'defecto': _defecto,
          'ubicacion': _ubicacionController.text.trim().toUpperCase(),
          'area': _area,
          'modelo': item.modelo.trim(),
          'tipo_inspeccion': _tipoInspeccion,
          'etapa_deteccion': etapa,
          'registrado_por': user.displayName,
        });
        if (!mounted) return;
        setState(() {
          _registeredCount++;
          _cart.removeWhere((cartItem) => cartItem.codigo == item.codigo);
        });
      }
      if (!mounted) return;
      Navigator.pop(context, _registeredCount);
    } on DmsException catch (error) {
      _showSnack(error.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _close() {
    Navigator.pop(context, _registeredCount == 0 ? null : _registeredCount);
  }

  String _normalizeCode(String value) {
    final code = extractPartCode(value) ?? value;
    return code.trim().toUpperCase();
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Requerido' : null;
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(snack(message, error: error));
  }
}

class _BatchCartItem {
  const _BatchCartItem({required this.codigo, required this.modelo});

  final String codigo;
  final String modelo;
}

enum _UserMenuAction { logout }

class _DefectTableColumn {
  const _DefectTableColumn(
    this.label,
    this.minWidth,
    this.flex, {
    this.alignment = Alignment.centerLeft,
  });

  final String label;
  final double minWidth;
  final double flex;
  final Alignment alignment;
}
