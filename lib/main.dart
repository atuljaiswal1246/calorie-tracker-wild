import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'models/profile.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final storage = await StorageService.init();
  AppColors.darkNotifier.value = storage.darkMode;
  NotificationService.init();
  runApp(CalorieApp(storage: storage, auth: AuthService()));
}

class CalorieApp extends StatefulWidget {
  final StorageService storage;
  final AuthService auth;

  CalorieApp({super.key, required this.storage, required this.auth});

  @override
  State<CalorieApp> createState() => _CalorieAppState();
}

enum _AppScreen { loading, welcome, signIn, onboarding, home }

class _CalorieAppState extends State<CalorieApp> {
  _AppScreen _screen = _AppScreen.loading;
  // Explicit intent for the next onboarding visit: none (fresh questions),
  // resume at sign-up (guest dropped mid-flow) or jump to pricing
  // (unpaid returner). Prevents reactive isSignedIn guessing from opening
  // wrong screens (e.g. pricing before the questionnaire).
  bool _onboardingAtSignup = false;
  bool _onboardingAtPricing = false;
  int? _onboardingAtStep;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final profileExists = widget.storage.profile != null;
    _onboardingAtSignup = false;
    _onboardingAtPricing = false;
    _onboardingAtStep = null;
    // If already signed in (app relaunch), restore session.
    if (widget.auth.isSignedIn) {
      await _onAuthenticated();
    } else if (profileExists) {
      // Guest with a saved plan: not paid -> sign-up, paid -> home.
      if (!widget.storage.isPaidOrSandbox(
        authEmail: widget.auth.currentUser?.email,
      )) {
        _onboardingAtSignup = true;
        _goTo(_AppScreen.onboarding);
      } else {
        _goTo(_AppScreen.home);
      }
    } else if (widget.storage.onboardingDraft != null) {
      // Mid-journey guest: resume at the saved step (goal page, sign-up
      // or payment) instead of restarting the whole questionnaire.
      final step = (widget.storage.onboardingDraft!['step'] as num?) ?? 0;
      _onboardingAtStep = step.toInt();
      _goTo(_AppScreen.onboarding);
    } else {
      _goTo(_AppScreen.welcome);
    }
  }

  Future<void> _onAuthenticated() async {
    final uid = widget.auth.currentUser!.uid;
    widget.storage.setUserId(uid);

    // Load cloud data (profile + entries + payment state) for this user.
    Profile? profile;
    try {
      profile = await widget.storage.loadProfileFromCloud();
      await widget.storage.loadEntriesFromCloud();
      await widget.storage.loadPaidFromCloud();
    } catch (_) {
      // Cloud not ready / offline — proceed with local data.
    }

    if (!mounted) return;
    if (profile == null) {
      // Signed in but never completed the questionnaire — must fill it.
      // Resume at the saved step if they were mid-journey (draft).
      _onboardingAtSignup = false;
      _onboardingAtPricing = false;
      final draft = widget.storage.onboardingDraft;
      _onboardingAtStep = draft != null
          ? ((draft['step'] as num?) ?? 0).toInt().clamp(0, 6)
          : null;
      _goTo(_AppScreen.onboarding);
    } else if (widget.storage.isPaidOrSandbox(
      authEmail: widget.auth.currentUser?.email,
    )) {
      // Subscribed (free trial or after) or sandbox dev — full access.
      _goTo(_AppScreen.home);
    } else {
      // Unpaid — pricing (Play offer starts the free trial).
      _onboardingAtSignup = false;
      _onboardingAtPricing = true;
      _goTo(_AppScreen.onboarding);
    }
  }

  void _goTo(_AppScreen screen) => setState(() => _screen = screen);

  ThemeData _theme(bool dark) {
    final brightness = dark ? Brightness.dark : Brightness.light;
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepOrange,
        brightness: brightness,
      ),
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: dark
          ? const Color(0xFF0E0F11)
          : const Color(0xFFFAF9F7),
      dialogBackgroundColor: dark ? const Color(0xFF1B1C1E) : Colors.white,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(fontFamily: 'Inter'),
        bodyMedium: TextStyle(fontFamily: 'Inter'),
        bodySmall: TextStyle(fontFamily: 'Inter'),
        titleLarge: TextStyle(fontFamily: 'Inter'),
        titleMedium: TextStyle(fontFamily: 'Inter'),
        titleSmall: TextStyle(fontFamily: 'Inter'),
        headlineLarge: TextStyle(fontFamily: 'Inter'),
        headlineMedium: TextStyle(fontFamily: 'Inter'),
        headlineSmall: TextStyle(fontFamily: 'Inter'),
        displayLarge: TextStyle(fontFamily: 'Inter'),
        displayMedium: TextStyle(fontFamily: 'Inter'),
        displaySmall: TextStyle(fontFamily: 'Inter'),
        labelLarge: TextStyle(fontFamily: 'Inter'),
        labelMedium: TextStyle(fontFamily: 'Inter'),
        labelSmall: TextStyle(fontFamily: 'Inter'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.darkNotifier,
      builder: (context, dark, _) => MaterialApp(
        title: 'Cal Matters',
        debugShowCheckedModeBanner: false,
        // Standard UX: tapping anywhere outside a text field dismisses the
        // keyboard, on every screen of the app.
        builder: (context, child) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        ),
        theme: _theme(dark),
        home: switch (_screen) {
          _AppScreen.loading => Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          _AppScreen.welcome => WelcomeScreen(
            // Get started goes straight to the questionnaire (no sign-up
            // screen first). Account creation happens after the plan.
            onGetStarted: () => _goTo(_AppScreen.onboarding),
            onSignIn: () => _goTo(_AppScreen.signIn),
          ),
          _AppScreen.signIn => AuthScreen(
            auth: widget.auth,
            isSignUp: false,
            onAuthenticated: _onAuthenticated,
            onBack: () => _goTo(_AppScreen.welcome),
          ),
          _AppScreen.onboarding => OnboardingScreen(
            storage: widget.storage,
            auth: widget.auth,
            onComplete: () => _goTo(_AppScreen.home),
            onBack: () {
              _onboardingAtSignup = false;
              _onboardingAtPricing = false;
              _onboardingAtStep = null;
              _goTo(_AppScreen.welcome);
            },
            startAtPricing: _onboardingAtPricing,
            startAtSignup: _onboardingAtSignup,
            startAtStep: _onboardingAtStep,
          ),
          _AppScreen.home => HomeScreen(
            storage: widget.storage,
            auth: widget.auth,
            onSignedOut: () {
              widget.storage.setUserId(null);
              _goTo(_AppScreen.welcome);
            },
            onResetGoals: () {
              // Reset goals = re-answer the questionnaire from scratch.
              _onboardingAtSignup = false;
              _onboardingAtPricing = false;
              _onboardingAtStep = null;
              widget.storage.clearOnboardingDraft();
              _goTo(_AppScreen.onboarding);
            },
          ),
        },
      ),
    );
  }
}
