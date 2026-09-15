import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../config/features.dart';
import '../services/auth_service.dart';
import '../services/funnel.dart';

enum _AuthMode { signIn, signUp }

/// The plan the guest just built, shown back to them on the sign-up screen so
/// the account feels like it is *saving their work* rather than a toll gate.
class PlanRecap {
  final String kcal;
  final String goal;
  final String workouts;

  const PlanRecap({
    required this.kcal,
    required this.goal,
    required this.workouts,
  });
}

class AuthScreen extends StatefulWidget {
  final AuthService auth;
  final VoidCallback onAuthenticated;
  final VoidCallback onBack;
  final bool isSignUp;
  final PlanRecap? recap;

  AuthScreen({
    super.key,
    required this.auth,
    required this.onAuthenticated,
    required this.onBack,
    this.isSignUp = false,
    this.recap,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late _AuthMode _mode;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _loading = false;
  bool _showEmailForm = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mode = widget.isSignUp ? _AuthMode.signUp : _AuthMode.signIn;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email first');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.auth.sendPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to your email')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_mode == _AuthMode.signUp) {
        await widget.auth.signUp(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await widget.auth.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      if (!mounted) return;
      Funnel.signup(
          _mode == _AuthMode.signUp ? 'email_signup' : 'email_signin');
      widget.onAuthenticated();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.auth.signInWithGoogle();
      if (!mounted) return;
      Funnel.signup('google');
      widget.onAuthenticated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().contains('cancelled')
            ? null
            : 'Google sign-in failed. Try again.';
      });
    }
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Try again.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  /// Native Apple sign-in. Only offered where it exists (iOS/macOS).
  Future<void> _signInWithApple() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.auth.signInWithApple();
      if (!mounted) return;
      Funnel.signup('apple');
      widget.onAuthenticated();
    } catch (e) {
      if (!mounted) return;
      final cancelled = e.toString().toLowerCase().contains('cancel');
      setState(() {
        _loading = false;
        _error = cancelled ? null : 'Apple sign-in failed. Try again.';
      });
    }
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == _AuthMode.signIn
          ? _AuthMode.signUp
          : _AuthMode.signIn;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _mode == _AuthMode.signUp;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: widget.onBack,
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Brand mark, so the screen belongs to the app they just
                  // spent six steps in.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(Icons.eco_rounded,
                              size: 32, color: Colors.black),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Cal Matters',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 26),
                  Text(
                    isSignUp ? 'Save your plan' : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    isSignUp
                        ? 'Create an account to keep your targets and start logging.'
                        : 'Sign in to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14.5,
                        height: 1.4,
                        color: Colors.black54),
                  ),
                  if (isSignUp && widget.recap != null) ...[
                    SizedBox(height: 20),
                    _RecapCard(recap: widget.recap!),
                  ],
                  SizedBox(height: 28),
                  if (!_showEmailForm) ...[
                    // Primary: Google (black fill, white logo + text)
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _loading ? null : _signInWithGoogle,
                        icon: _GoogleIcon(),
                        label: Text(
                          isSignUp
                              ? 'Sign up with Google'
                              : 'Sign in with Google',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    if (Features.appleSignIn &&
                        (Platform.isIOS || Platform.isMacOS)) ...[
                      SizedBox(height: 14),
                      SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _loading ? null : _signInWithApple,
                          icon: FaIcon(FontAwesomeIcons.apple, size: 23),
                          label: Text(
                            isSignUp
                                ? 'Sign up with Apple'
                                : 'Sign in with Apple',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 14),
                    // Secondary: Continue with email (white fill)
                    SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.black26),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _loading
                            ? null
                            : () => setState(() => _showEmailForm = true),
                        icon: Icon(Icons.email_outlined,
                            size: 22, color: Colors.black87),
                        label: Text(
                          'Continue with email',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Email form
                    TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_passwordFocus);
                      },
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon:
                            Icon(Icons.email_outlined, color: Colors.black54),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isEmpty || !val.contains('@')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: _obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_loading) _submit();
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline,
                            color: Colors.black54),
                        border: OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        final val = v ?? '';
                        if (val.isEmpty) return 'Enter your password';
                        if (isSignUp && val.length < 6) {
                          return 'Minimum 6 characters';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ],
                    SizedBox(height: 24),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                isSignUp ? 'Create account' : 'Sign in',
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                    SizedBox(height: 10),
                    if (!isSignUp)
                      Center(
                        child: TextButton(
                          onPressed: _loading ? null : _forgotPassword,
                          child: Text('Forgot password?'),
                        ),
                      ),
                    if (!isSignUp) SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() => _showEmailForm = false),
                        child: Text('Go back',
                            style: TextStyle(color: Colors.black54)),
                      ),
                    ),
                  ],
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isSignUp
                            ? 'Already have an account? '
                            : 'New here? ',
                        style:
                            TextStyle(color: Colors.black54),
                      ),
                      GestureDetector(
                        onTap: _loading ? null : _toggleMode,
                        child: Text(
                          isSignUp ? 'Sign in' : 'Create account',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  Text(
                    'By continuing you agree to our Terms of Service and '
                    'Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11, height: 1.5, color: Colors.black38),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FaIcon(FontAwesomeIcons.google, size: 20, color: Colors.white);
  }
}

/// The guest's plan, echoed back on the sign-up screen.
class _RecapCard extends StatelessWidget {
  final PlanRecap recap;

  const _RecapCard({required this.recap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3E2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E4CD), width: 1.2),
      ),
      child: Row(
        children: [
          _cell(recap.kcal, 'kcal / day'),
          _divider(),
          _cell(recap.goal, 'your goal'),
          _divider(),
          _cell(recap.workouts, 'workouts / week'),
        ],
      ),
    );
  }

  Widget _cell(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 30,
        color: Colors.black.withValues(alpha: 0.08),
      );
}
