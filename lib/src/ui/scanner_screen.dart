import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/code_parser.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late final MobileScannerController _controller;
  bool _returned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoZoom: true,
      detectionSpeed: DetectionSpeed.unrestricted,
      formats: const [BarcodeFormat.all],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear codigo'),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            onPressed: _controller.toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
          IconButton(
            tooltip: 'Cambiar camara',
            onPressed: _controller.switchCamera,
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            tapToFocus: true,
            placeholderBuilder: (_) => const ColoredBox(
              color: Colors.black,
              child: Center(child: Text('Iniciando camara...')),
            ),
            errorBuilder: (_, error) => ColoredBox(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Camara no disponible: ${error.errorCode.message}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            onDetect: (capture) {
              if (_returned) return;
              final value = capture.barcodes
                  .map((barcode) => barcode.rawValue)
                  .whereType<String>()
                  .where((text) => text.trim().isNotEmpty)
                  .firstOrNull;
              final code = value == null ? null : extractPartCode(value);
              if (code == null) return;
              _returned = true;
              Navigator.of(context).pop(code);
            },
          ),
          Center(
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.65),
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Alinea el QR o codigo de barras dentro del marco',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
