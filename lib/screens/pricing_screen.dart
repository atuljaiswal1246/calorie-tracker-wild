import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/billing_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';

/// The paywall. Reached after onboarding (plan ready -> sign up -> here) or
/// from the Settings developer preview. Purchases go through Google Play /
/// the App Store via [BillingService]; the design is documented and locked in
/// AGENTS.md ("Payment screen").
///
/// Layout rule: the hero is Expanded so BOTH plan cards stay visible without
/// scrolling, and the copy is identical on both stores.

// ---------------- Pricing screen ----------------
class PricingScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback onPaid;

  /// Optional — when provided (walking the funnel, or the dev preview) a back
  /// control is shown at the top.
  final VoidCallback? onBack;

  PricingScreen({
    required this.storage,
    required this.onPaid,
    this.onBack,
  });

  @override
  State<PricingScreen> createState() => PricingScreenState();
}

class PricingScreenState extends State<PricingScreen> {
  bool _yearly = true; // yearly selected by default
  bool _processing = false;
  bool _approved = false;
  late final BillingService _billing;

  static const _monthlyPrice = 100;
  static const _yearlyPrice = 1000;

  /// "₹1,000" style — symbol + thousands separator.
  static String _inr(int amount) {
    final s = amount.toString();
    return '₹${s.length > 3 ? s.substring(0, s.length - 3) + ',' + s.substring(s.length - 3) : s}';
  }

  List<ProductDetails> _products = [];

  /// "1,829 kcal/day · Lose 5 kg · 3–5×/week" from the plan they just built.
  String get _planLine {
    final p = widget.storage.profile;
    if (p == null) return 'Your personal targets are ready';
    final bits = <String>['${p.calorieGoal} kcal/day'];
    final t = p.targetWeightKg;
    if (p.goal == 'lose' && t != null && t > 0) {
      bits.add('Lose ${(p.weightKg - t).round()} kg');
    } else if (p.goal == 'gain' && t != null && t > 0) {
      bits.add('Gain ${(t - p.weightKg).round()} kg');
    } else if (p.goal == 'maintain') {
      bits.add('Maintain weight');
    }
    final w = switch (p.workoutFreq) {
      'none' => 'No workouts',
      '1to2' => '1–2×/week',
      '3to5' => '3–5×/week',
      '6plus' => '6+×/week',
      _ => null,
    };
    if (w != null) bits.add(w);
    return bits.join(' · ');
  }

  Widget _legalLink(String text, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          color: AppColors.muted,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _legalDot() => Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text('·',
            style: TextStyle(fontSize: 11.5, color: AppColors.faint)),
      );

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  int get _savingsPercent {
    final annualIfMonthly = _monthlyPrice * 12;
    return ((annualIfMonthly - _yearlyPrice) / annualIfMonthly * 100).round();
  }

  @override
  void initState() {
    super.initState();
    _billing = BillingService(widget.storage);
    _billing.onStatusChanged = _handleStatus;
    _loadProducts();
  }

  /// The purchase stream flips billing.status asynchronously (after the
  /// Play flow closes), so react to it here — otherwise a completed payment
  /// would leave the user stuck on the payment wall until relaunch.
  void _handleStatus() {
    if (!mounted) return;
    setState(() {});
    if (_billing.status == BillingStatus.subscribed && !_approved) {
      setState(() => _approved = true);
      Future.delayed(Duration(milliseconds: 1200), () {
        if (!mounted) return;
        widget.onPaid();
      });
    }
  }

  Future<void> _loadProducts() async {
    final products = await _billing.loadProducts();
    if (!mounted) return;
    setState(() {
      _products = products;
      _processing = false;
    });
  }

  /// Prefer the free-trial OFFER entry (Google Play returns one
  /// ProductDetails per offer; the trial one has rawPrice <= 0).
  /// Falling back to the base plan if no offer is available.
  ProductDetails? get _monthlyProduct =>
      _billing.productFor(_products, BillingService.monthlyId,
          preferTrial: true);
  ProductDetails? get _yearlyProduct =>
      _billing.productFor(_products, BillingService.yearlyId,
          preferTrial: true);

  Future<void> _continue() async {
    final product = _yearly ? _yearlyProduct : _monthlyProduct;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchases aren\'t available right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _processing = true);
    await _billing.buyUnit(product);
    if (!mounted) return;
    setState(() => _processing = false);

    // Purchase flow returns; stream handles final status.
    // If status became subscribed (immediate), finish.
    if (_billing.status == BillingStatus.subscribed) {
      _handleStatus();
    }
    setState(() {});
  }

  Future<void> _restore() async {
    setState(() => _processing = true);
    await _billing.restore();
    if (!mounted) return;
    setState(() => _processing = false);
    // Restore completes via the purchase stream (restored purchases fire
    // purchaseStream with PurchaseStatus.restored), which sets paid=true.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Restoring your purchases...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_approved) {
      return _PaymentApprovedScreen();
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.onBack != null)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onBack,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.ink.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_back_rounded,
                            size: 18, color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(height: 6),
            // Everything must fit without scrolling so BOTH plans stay
            // visible for comparison: the hero absorbs whatever space is left
            // after the fixed content below it.
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Keep your plan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.6,
                      ),
                    ),
                    SizedBox(height: 9),
                    Text(
                      _planLine,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13.5, color: AppColors.muted),
                    ),
                    SizedBox(height: 16),
                    Expanded(child: _PaywallHero()),
                    SizedBox(height: 16),
                    _BenefitRow('Snap a photo → instant calories & macros'),
                    _BenefitRow('1,800+ Indian foods, works offline'),
                    _BenefitRow('Your targets, pace & weekly progress'),
                    SizedBox(height: 12),
                    _PlanOptionCard(
                      selected: _yearly,
                      badge: 'SAVE $_savingsPercent%',
                      left: 'Annual',
                      right: _inr(_yearlyPrice),
                      period: '/ year',
                      sub:
                          '≈ ${_inr((_yearlyPrice / 12).round())}/month · 3 days free',
                      onTap: () => setState(() => _yearly = true),
                    ),
                    SizedBox(height: 10),
                    _PlanOptionCard(
                      selected: !_yearly,
                      left: 'Monthly',
                      right: _inr(_monthlyPrice),
                      period: '/ month',
                      sub: '3 days free',
                      onTap: () => setState(() => _yearly = false),
                    ),
                    SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            // Continue button + fine print
            ColoredBox(
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: StadiumBorder(),
                          ),
                          onPressed: _processing ? null : _continue,
                          child: _processing
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  'Start 3-day free trial',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3),
                                ),
                        ),
                      ),
                      SizedBox(height: 9),
                      Text(
                        _yearly
                            ? 'Then ${_inr(_yearlyPrice)}/year. Cancel anytime.'
                            : 'Then ${_inr(_monthlyPrice)}/month. Cancel anytime.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _legalLink('Terms',
                              () => _open('https://calorie-tracker-80a0b.web.app/terms.html')),
                          _legalDot(),
                          _legalLink('Privacy',
                              () => _open('https://calorie-tracker-80a0b.web.app/privacy.html')),
                          _legalDot(),
                          _legalLink('Restore purchases',
                              _processing ? null : _restore),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Pricing hero placeholder (phone mockup) ----------------
// ---------------- Selectable plan option ----------------
/// The paywall hero: a real meal with its macro breakdown floating over it —
/// the app's core promise (photo -> calories & macros) shown, not described.
class _PaywallHero extends StatelessWidget {
  _PaywallHero();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/onboarding/food_palak_paneer.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: const Color(0xFFFBF3E2),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: AppColors.green,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 7),
                        Text('Palak Paneer',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink)),
                        const Spacer(),
                        Text('265 kcal',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _PaywallMacro(AppColors.green, 'Protein', '14g'),
                        _PaywallMacro(AppColors.carbs, 'Carbs', '9g'),
                        _PaywallMacro(
                            const Color(0xFF8B5CF6), 'Fats', '19g'),
                      ],
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
}

/// Compact macro chip (dot · label · grams) — keeps the hero card short so
/// most of the dish stays visible.
class _PaywallMacro extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  _PaywallMacro(this.color, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 10, color: AppColors.muted)),
          SizedBox(width: 3),
          Flexible(
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
          ),
        ],
      ),
    );
  }
}

/// One "what you get" line.
class _BenefitRow extends StatelessWidget {
  final String text;

  _BenefitRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.check_rounded,
                size: 13, color: AppColors.green),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
          ),
        ],
      ),
    );
  }
}

class _PlanOptionCard extends StatelessWidget {
  final bool selected;
  final String? badge;
  final String left;
  final String right;
  final String? period;
  final String? sub;
  final VoidCallback onTap;

  _PlanOptionCard({
    required this.selected,
    required this.left,
    required this.right,
    required this.onTap,
    this.badge,
    this.period,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.black : Colors.black12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(left,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.black)),
                if (badge != null) ...[
                  SizedBox(width: 8),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(badge!,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3)),
                  ),
                ],
                Spacer(),
                Text.rich(
                  TextSpan(
                    text: right,
                    style: TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w800),
                    children: period == null
                        ? null
                        : [
                            TextSpan(
                              text: ' $period',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54),
                            ),
                          ],
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Colors.black : Colors.transparent,
                    border: Border.all(
                      color: selected ? Colors.black : AppColors.divider,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check,
                          size: 12, color: Colors.white)
                      : null,
                ),
              ],
            ),
            if (sub != null) ...[
              SizedBox(height: 4),
              Text(sub!,
                  style: TextStyle(
                      fontSize: 11.5, color: Colors.black54)),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------- Payment approved (testing phase) ----------------
class _PaymentApprovedScreen extends StatelessWidget {
  _PaymentApprovedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Icon(Icons.check_circle,
                    color: Colors.green, size: 80),
              ),
              SizedBox(height: 20),
              Text('Payment approved!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: -0.5)),
              SizedBox(height: 8),
              Text('Welcome to Cal Matters.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

