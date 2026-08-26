import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../services/gemini_service.dart';
import '../services/openai_service.dart';

class ApiKeySetupScreen extends StatefulWidget {
  final StorageService storage;
  const ApiKeySetupScreen({super.key, required this.storage});

  @override
  State<ApiKeySetupScreen> createState() => _ApiKeySetupScreenState();
}

class _ApiKeySetupScreenState extends State<ApiKeySetupScreen> {
  static const _bg = Color(0xFFFAF9F7);
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF8E8E93);
  static const _green = Color(0xFF34C759);

  String _provider = 'gemini';
  final _keyController = TextEditingController();
  bool _testing = false;
  String? _testResult; // 'success', 'error', or null
  String? _errorMsg;
  bool _showGuide = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _provider = widget.storage.provider ?? 'gemini';
    if (_provider == 'openai') {
      _keyController.text = widget.storage.apiKey ?? '';
    } else {
      _keyController.text = widget.storage.geminiKey ?? '';
    }
    if (_keyController.text.isEmpty) _showGuide = true;
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _testKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    setState(() {
      _testing = true;
      _testResult = null;
      _errorMsg = null;
    });

    try {
      bool ok;
      if (_provider == 'gemini') {
        ok = await GeminiService.testKey(key);
      } else {
        ok = await OpenAIService.testKey(key);
      }
      setState(() {
        _testResult = ok ? 'success' : 'error';
        _errorMsg = ok ? null : 'Invalid key. Please check and try again.';
      });
    } catch (e) {
      setState(() {
        _testResult = 'error';
        _errorMsg = 'Connection error. Check your internet.';
      });
    } finally {
      setState(() => _testing = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _keyController.text = data!.text!;
      setState(() {});
    }
  }

  Future<void> _save() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    if (_provider == 'gemini') {
      await widget.storage.saveGeminiKey(key);
    } else {
      await widget.storage.saveApiKey(key);
    }
    await widget.storage.saveProvider(_provider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key saved!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _ink,
        title: const Text(
          'API Key Setup',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: _ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        children: [
          // Why section
          _whySection(),
          const SizedBox(height: 20),
          // Provider picker
          _providerSection(),
          const SizedBox(height: 20),
          // Key input
          _keyInputSection(),
          const SizedBox(height: 20),
          // Guide
          if (_showGuide) _guideSection(),
          // Save button
          const SizedBox(height: 10),
          _saveButton(),
        ],
      ),
    );
  }

  Widget _whySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _ink.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.key, size: 20, color: _ink),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Why do I need this?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Cal Matters uses AI to analyze your food photos. You need an API key so the app can send photos to the AI for analysis.',
            style: TextStyle(
              fontSize: 14,
              color: _muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: _green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your key stays on this device. We never see it.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your AI provider',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Both work great. Gemini has a free tier.',
            style: TextStyle(fontSize: 13, color: _muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _providerOption(
                  label: 'Google Gemini',
                  subtitle: 'Free tier available',
                  icon: Icons.auto_awesome,
                  selected: _provider == 'gemini',
                  onTap: () => setState(() {
                    _provider = 'gemini';
                    _testResult = null;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _providerOption(
                  label: 'OpenAI',
                  subtitle: 'Pay per use',
                  icon: Icons.psychology,
                  selected: _provider == 'openai',
                  onTap: () => setState(() {
                    _provider = 'openai';
                    _testResult = null;
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _providerOption({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _ink : _bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _ink : const Color(0xFFE5E5EA),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: selected ? Colors.white : _ink,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: selected ? Colors.white70 : _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _keyInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _provider == 'gemini' ? 'Gemini API key' : 'OpenAI API key',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const Spacer(),
              // Paste button
              GestureDetector(
                onTap: _pasteFromClipboard,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _ink.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.paste, size: 14, color: _ink),
                      SizedBox(width: 4),
                      Text(
                        'Paste',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _keyController,
            obscureText: true,
            style: const TextStyle(
              fontSize: 15,
              fontFamily: 'monospace',
              color: _ink,
            ),
            onChanged: (_) => setState(() {
              _testResult = null;
              _errorMsg = null;
            }),
            decoration: InputDecoration(
              hintText: _provider == 'gemini' ? 'AIza...' : 'sk-...',
              hintStyle: const TextStyle(color: _muted),
              filled: true,
              fillColor: _bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _testResult == 'success'
                      ? _green
                      : _testResult == 'error'
                          ? const Color(0xFFFF3B30)
                          : _ink,
                  width: 2,
                ),
              ),
              suffixIcon: _testResult != null
                  ? Icon(
                      _testResult == 'success'
                          ? Icons.check_circle
                          : Icons.error,
                      color: _testResult == 'success'
                          ? _green
                          : const Color(0xFFFF3B30),
                    )
                  : null,
            ),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMsg!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFFF3B30),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Test key button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _testing || _keyController.text.trim().isEmpty
                  ? null
                  : _testKey,
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                side: const BorderSide(color: Color(0xFFE5E5EA)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _testing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Test key',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showGuide = !_showGuide),
            child: Row(
              children: [
                const Icon(Icons.help_outline, size: 20, color: _ink),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'How to get a key',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
                Icon(
                  _showGuide
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: _muted,
                ),
              ],
            ),
          ),
          if (_showGuide) ...[
            const SizedBox(height: 16),
            _guideStep(
              '1',
              _provider == 'gemini'
                  ? 'Go to aistudio.google.com'
                  : 'Go to platform.openai.com',
              _provider == 'gemini'
                  ? 'Visit aistudio.google.com and sign in with your Google account.'
                  : 'Visit platform.openai.com and sign in (or create an account).',
            ),
            const SizedBox(height: 12),
            _guideStep(
              '2',
              'Create an API key',
              _provider == 'gemini'
                  ? 'Click "Get API key" → "Create API key" → Copy it.'
                  : 'Go to API Keys → "Create new secret key" → Copy it.',
            ),
            const SizedBox(height: 12),
            _guideStep(
              '3',
              'Paste it here',
              'Paste the key above and tap "Test key" to verify it works.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_money, size: 16, color: Color(0xFFFF9500)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _provider == 'gemini'
                          ? 'Gemini has a free tier — most users won\'t pay anything.'
                          : 'OpenAI costs ~\$0.01 per photo analysis (~\$1-2/month for regular use).',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _guideStep(String number, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _ink,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 13,
                  color: _muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _saveButton() {
    final hasKey = _keyController.text.trim().isNotEmpty;
    final tested = _testResult == 'success';

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: hasKey ? _save : null,
        style: FilledButton.styleFrom(
          backgroundColor: _ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _ink.withOpacity(0.3),
          shape: const StadiumBorder(),
        ),
        child: Text(
          tested ? 'Save & continue' : 'Save key',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}
