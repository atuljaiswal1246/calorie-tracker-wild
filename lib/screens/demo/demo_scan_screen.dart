import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/barcode_service.dart';
import '../../services/food_search_service.dart';
import '../../theme/app_colors.dart';
import 'demo_common.dart';

class _ScanResult {
  final String title;
  final String subtitle;
  final String badge;
  final int kcal;
  final double protein;
  final double carbs;
  final double fat;

  const _ScanResult({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory _ScanResult.fromBarcode(BarcodeResult b) => _ScanResult(
        title: b.name.isEmpty ? 'Scanned product' : b.name,
        subtitle: b.brand.isEmpty ? b.servingSize : b.brand,
        badge: 'Open Food Facts',
        kcal: b.calories,
        protein: b.protein,
        carbs: b.carbs,
        fat: b.fat,
      );

  factory _ScanResult.fromDb(FoodDBItem f) => _ScanResult(
        title: f.name,
        subtitle: f.nameHindi.isEmpty ? 'per 100 g' : f.nameHindi,
        badge: 'Indian food DB',
        kcal: f.calories,
        protein: f.protein,
        carbs: f.carbs,
        fat: f.fat,
      );
}

/// Try-before-you-buy demo: point at a barcode, or tap "try a sample" and
/// watch a real nutrition breakdown slide up. No account needed.
class DemoScanScreen extends StatefulWidget {
  final VoidCallback onGetStarted;

  const DemoScanScreen({super.key, required this.onGetStarted});

  @override
  State<DemoScanScreen> createState() => _DemoScanScreenState();
}

class _DemoScanScreenState extends State<DemoScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat(reverse: true);

  MobileScannerController? _controller;
  final Set<String> _seen = {};
  bool _busy = false;
  _ScanResult? _result;

  @override
  void initState() {
    super.initState();
    try {
      _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
    } catch (_) {
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _line.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _result != null) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || !_seen.add(code)) return;
    _busy = true;
    final r = await BarcodeService.lookup(code);
    if (!mounted) return;
    _busy = false;
    if (r.result != null) {
      _reveal(_ScanResult.fromBarcode(r.result!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No match for that barcode — try a sample.')),
      );
    }
  }

  Future<void> _trySample() async {
    final list = await FoodSearchService.search('paneer butter masala');
    final item = list.isNotEmpty
        ? list.first
        : (await FoodSearchService.search('dal')).firstOrNull;
    if (!mounted || item == null) return;
    _reveal(_ScanResult.fromDb(item));
  }

  void _reveal(_ScanResult r) {
    HapticFeedback.mediumImpact();
    setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _preview()),
          // Dim the edges so the viewfinder pops
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.85,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(child: _viewfinder()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 20, color: Colors.white),
                        ),
                      ),
                      const Spacer(),
                      const DemoBadge(),
                    ],
                  ),
                ),
                const Spacer(),
                if (_result == null) ...[
                  const Text('Point at a barcode',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('or try a sample below',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12.5)),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _trySample,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 18, color: AppColors.carbs),
                          const SizedBox(width: 8),
                          Text('Try a sample scan',
                              style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ] else
                  const SizedBox(height: 20),
              ],
            ),
          ),
          // Result card slides up
          AnimatedPositioned(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: _result == null ? -420 : 0,
            child: _result == null
                ? const SizedBox.shrink()
                : _ResultCard(
                    result: _result!,
                    onClose: () => setState(() => _result = null),
                    onGetStarted: widget.onGetStarted,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final c = _controller;
    if (c == null) return _fallback();
    return MobileScanner(
      controller: c,
      onDetect: _onDetect,
      errorBuilder: (_, __, ___) => _fallback(),
      placeholderBuilder: (_, __) => _fallback(),
    );
  }

  Widget _fallback() => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF20242B), Color(0xFF101216)],
          ),
        ),
      );

  Widget _viewfinder() {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5),
                ),
              ),
              AnimatedBuilder(
                animation: _line,
                builder: (_, __) => Align(
                  alignment: Alignment(0, -1 + 2 * _line.value),
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.carbs,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.carbs.withValues(alpha: 0.8),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final _ScanResult result;
  final VoidCallback onClose;
  final VoidCallback onGetStarted;

  const _ResultCard({
    required this.result,
    required this.onClose,
    required this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                              letterSpacing: -0.4)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(result.subtitle,
                              style: TextStyle(
                                  fontSize: 12.5, color: AppColors.muted)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(result.badge,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.green)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(Icons.close_rounded,
                      size: 20, color: AppColors.faint),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                RingStat(
                  pct: (result.kcal / 600).clamp(0, 1),
                  color: AppColors.green,
                  size: 92,
                  stroke: 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CountUp(
                        value: result.kcal,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink),
                      ),
                      Text('kcal',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      MacroBar(
                          label: 'Protein',
                          value: '${result.protein.toStringAsFixed(0)}g',
                          pct: result.protein / 40,
                          color: AppColors.green),
                      MacroBar(
                          label: 'Carbs',
                          value: '${result.carbs.toStringAsFixed(0)}g',
                          pct: result.carbs / 80,
                          color: AppColors.carbs),
                      MacroBar(
                          label: 'Fats',
                          value: '${result.fat.toStringAsFixed(0)}g',
                          pct: result.fat / 40,
                          color: const Color(0xFF8B5CF6)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DemoCta(label: 'Get started to log this', onTap: onGetStarted),
          ],
        ),
      ),
    );
  }
}
