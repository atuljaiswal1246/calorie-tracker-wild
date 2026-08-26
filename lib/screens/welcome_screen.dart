import 'dart:async';

import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  const WelcomeScreen({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _controller = PageController();
  int _current = 0;
  Timer? _autoplay;

  @override
  void initState() {
    super.initState();
    _autoplay = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients) return;
      final next = (_current + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    // ---- Skip ----
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: widget.onGetStarted,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ---- Carousel (~60% of screen) ----
                    SizedBox(
                      height: constraints.maxHeight * 0.58,
                      child: Column(
                        children: [
                          Expanded(
                            child: PageView.builder(
                              controller: _controller,
                              itemCount: _slides.length,
                              onPageChanged: (i) =>
                                  setState(() => _current = i),
                              itemBuilder: (context, index) =>
                                  _slides[index],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _Dots(count: _slides.length, current: _current),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // ---- Heading (value proposition) ----
                    const Text(
                      'Know your calories\nfrom a single photo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 34,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // ---- CTA button ----
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: widget.onGetStarted,
                        child: const Text(
                          'Get started',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account? ',
                            style: TextStyle(color: Colors.black54)),
                        GestureDetector(
                          onTap: widget.onSignIn,
                          child: const Text('Sign in',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  final _slides = <Widget>[
    const _Slide(
      label: 'Snap a photo',
      caption: 'Take a picture of your meal',
      child: _CameraMock(),
    ),
    const _Slide(
      label: 'AI breaks it down',
      caption: 'Instant calories & macros',
      child: _AnalysisMock(),
    ),
    const _Slide(
      label: 'Track your day',
      caption: 'See your progress at a glance',
      child: _DashboardMock(),
    ),
  ];
}

class _Slide extends StatelessWidget {
  final String label;
  final String caption;
  final Widget child;

  const _Slide({
    required this.label,
    required this.caption,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Phone mockup scales down to fit whatever height is available.
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: child,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(label,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black)),
        const SizedBox(height: 4),
        Text(caption,
            style: const TextStyle(fontSize: 14, color: Colors.black54)),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int current;

  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? Colors.black : Colors.black26,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ---- Phone mockup shell ----
class _Phone extends StatelessWidget {
  final Widget child;

  const _Phone({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      height: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.black12, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(29),
        child: Column(
          children: [
            _StatusBar(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      color: const Color(0xFFF6F6F6),
      alignment: Alignment.center,
      child: Container(
        width: 70,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

// ---- Slide 1: Camera ----
class _CameraMock extends StatelessWidget {
  const _CameraMock();

  @override
  Widget build(BuildContext context) {
    return _Phone(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Log a meal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFFF1E9DC),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.restaurant,
                    size: 64, color: Colors.black26),
              ),
            ),
            SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined,
                    size: 22, color: Colors.black54),
                SizedBox(width: 24),
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.black,
                  child: Icon(Icons.camera_alt,
                      color: Colors.white, size: 24),
                ),
                SizedBox(width: 24),
                Icon(Icons.flip, size: 22, color: Colors.black54),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Slide 2: AI analysis ----
class _AnalysisMock extends StatelessWidget {
  const _AnalysisMock();

  @override
  Widget build(BuildContext context) {
    return _Phone(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detected foods',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Expanded(
              child: Column(
                children: [
                  _Row(name: 'Paneer Butter Masala', cal: 420),
                  SizedBox(height: 8),
                  _Row(name: '2 Butter Roti', cal: 180),
                  SizedBox(height: 8),
                  _Row(name: 'Dal Tadka', cal: 160),
                  SizedBox(height: 8),
                  _Row(name: 'Jeera Rice', cal: 210),
                ],
              ),
            ),
            Divider(color: Colors.black12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                Text('970 kcal',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Colors.black)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String name;
  final int cal;

  const _Row({required this.name, required this.cal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Text('$cal',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ---- Slide 3: Dashboard ----
class _DashboardMock extends StatelessWidget {
  const _DashboardMock();

  @override
  Widget build(BuildContext context) {
    return _Phone(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's calories",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text('1520',
                style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    height: 1)),
            Text('of 1829 kcal goal',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
            SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(6)),
              child: LinearProgressIndicator(
                value: 0.83,
                minHeight: 10,
                color: Colors.black,
                backgroundColor: Color(0xFFEEEEEE),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _Macro(label: 'Protein', value: '68g')),
                SizedBox(width: 8),
                Expanded(child: _Macro(label: 'Carbs', value: '190g')),
                SizedBox(width: 8),
                Expanded(child: _Macro(label: 'Fat', value: '55g')),
              ],
            ),
            Spacer(),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Center(
                  child: Text('Log a meal',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final String value;

  const _Macro({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }
}
