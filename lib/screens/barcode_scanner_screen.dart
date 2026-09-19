import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/barcode_service.dart';
import '../services/storage_service.dart';
import 'barcode_result_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final StorageService storage;

  BarcodeScannerScreen({super.key, required this.storage});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController? _controller;
  bool _scanned = false;
  bool _flashOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    setState(() => _scanned = true);
    _lookupBarcode(barcode);
  }

  Future<void> _enterManually() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Enter barcode'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: 'e.g. 8901058100219',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Look up'),
          ),
        ],
      ),
    );
    if (code != null && code.isNotEmpty && mounted) {
      _lookupBarcode(code);
    }
  }

  Future<void> _lookupBarcode(String barcode) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Looking up product...'),
              ],
            ),
          ),
        ),
      ),
    );

    final result = await BarcodeService.lookup(barcode);

    if (!mounted) return;
    Navigator.pop(context); // dismiss loading

    if (result.result == null || !result.result!.isValid) {
      setState(() => _scanned = false);
      final msg = result.error == BarcodeError.network
          ? 'No internet connection. Check your WiFi or mobile data.'
          : 'Product not found for barcode: $barcode';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeResultScreen(
          result: result.result!,
          storage: widget.storage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Scan overlay
          CustomPaint(
            painter: _ScanOverlayPainter(),
            size: Size.infinite,
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await _controller?.toggleTorch();
                        setState(() => _flashOn = !_flashOn);
                      },
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _flashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom hint
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Point camera at barcode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AppType.bodyStrong,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        _scanned = false;
                        _controller?.start();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Scan again',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: AppType.body,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    GestureDetector(
                      onTap: _enterManually,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Enter code manually',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: AppType.body,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final boxSize = size.width * 0.7;
    final left = (size.width - boxSize) / 2;
    final top = (size.height - boxSize) / 2;

    // Dark overlay
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Clear center
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawRect(
      Rect.fromLTWH(left, top, boxSize, boxSize),
      clearPaint,
    );

    // Corner brackets
    final bracketPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cornerLen = boxSize * 0.15;
    final r = 12.0;

    // Top-left
    final tl = Path()
      ..moveTo(left + r, top)
      ..lineTo(left + cornerLen, top)
      ..moveTo(left, top + r)
      ..lineTo(left, top + cornerLen);
    canvas.drawPath(tl, bracketPaint);

    // Top-right
    final tr = Path()
      ..moveTo(left + boxSize - cornerLen, top)
      ..lineTo(left + boxSize - r, top)
      ..moveTo(left + boxSize, top + r)
      ..lineTo(left + boxSize, top + cornerLen);
    canvas.drawPath(tr, bracketPaint);

    // Bottom-left
    final bl = Path()
      ..moveTo(left + r, top + boxSize)
      ..lineTo(left + cornerLen, top + boxSize)
      ..moveTo(left, top + boxSize - r)
      ..lineTo(left, top + boxSize - cornerLen);
    canvas.drawPath(bl, bracketPaint);

    // Bottom-right
    final br = Path()
      ..moveTo(left + boxSize - cornerLen, top + boxSize)
      ..lineTo(left + boxSize - r, top + boxSize)
      ..moveTo(left + boxSize, top + boxSize - r)
      ..lineTo(left + boxSize, top + boxSize - cornerLen);
    canvas.drawPath(br, bracketPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
