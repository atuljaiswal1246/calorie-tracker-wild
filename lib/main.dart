import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'models/profile.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final storage = await StorageService.init();
  runApp(CalorieApp(storage: storage, auth: AuthService()));
}

class CalorieApp extends StatefulWidget {
  final StorageService storage;
  final AuthService auth;

  const CalorieApp({super.key, required this.storage, required this.auth});

  @override
  State<CalorieApp> createState() => _CalorieAppState();
}

enum _AppScreen { loading, welcome, signIn, onboarding, home }

class _CalorieAppState extends State<CalorieApp> {
  _AppScreen _screen = _AppScreen.loading;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // If already signed in (app relaunch), restore session.
    if (widget.auth.isSignedIn) {
      await _onAuthenticated();
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
      _goTo(_AppScreen.onboarding);
    } else if (!widget.storage.isPaid) {
      // Has a profile but never paid — grandfather in existing users.
      await widget.storage.savePaid(true);
      _goTo(_AppScreen.home);
    } else {
      _goTo(_AppScreen.home);
    }
  }

  void _goTo(_AppScreen screen) => setState(() => _screen = screen);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cal Matters',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
        fontFamily: 'Inter',
        textTheme: const TextTheme(
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
      ),
      home: switch (_screen) {
        _AppScreen.loading =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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
            onBack: () => _goTo(_AppScreen.welcome),
            startAtPricing: widget.storage.isPaid == false &&
                widget.storage.profile != null,
          ),
        _AppScreen.home => HomeScreen(
            storage: widget.storage,
            auth: widget.auth,
            onSignedOut: () {
              widget.storage.setUserId(null);
              _goTo(_AppScreen.welcome);
            },
          ),
      },
    );
  }
}