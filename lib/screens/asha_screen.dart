import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/shop.dart';
import '../services/asha_prompts.dart';
import '../services/gamification_controller.dart';
import '../services/openai_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Asha — AI nutrition assistant (our own "Ria").
/// Knows the user's goal + today's logged food, gives Indian-food-aware
/// advice in simple Hindi/English-style language.
class AshaScreen extends StatefulWidget {
  final StorageService storage;

  AshaScreen({super.key, required this.storage});

  @override
  State<AshaScreen> createState() => _AshaScreenState();
}

class _AshaScreenState extends State<AshaScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<({String role, String text})> _messages = [];
  bool _sending = false;
  String? _error;
  String _systemPrompt = '';
  String _currentPrompt = AshaPrompts.random;

  static const _hints = [
    'Is yogurt or a banana better after dinner?',
    'I\'m at 1500 kcal. What can I eat for dinner?',
    'My protein is low today. What should I add?',
    'Is eating rice at night bad?',
    'What should I eat before a morning run?',
  ];

  @override
  void initState() {
    super.initState();
    _buildSystemPrompt();
    _currentPrompt = AshaPrompts.random;
  }

  void _buildSystemPrompt() {
    final profile = widget.storage.profile;
    if (profile == null) {
      _systemPrompt = 'You are Asha, a warm, practical AI nutrition assistant.';
      return;
    }
    final today = DateTime.now();
    final entries = widget.storage.entries.where((e) => e.isOn(today)).toList();

    final totalCal = entries.fold<int>(0, (s, e) => s + e.totalCalories);
    final totalP = entries.fold<double>(0, (s, e) => s + e.totalProtein);
    final totalC = entries.fold<double>(0, (s, e) => s + e.totalCarbs);
    final totalF = entries.fold<double>(0, (s, e) => s + e.totalFat);
    final foods = entries
        .expand((e) => e.items)
        .map((i) => '- ${i.name} (${i.calories} kcal)')
        .join('\n');

    final goalLabel = switch (profile.goal) {
      'lose' => 'lose weight',
      'gain' => 'gain weight / build muscle',
      'exploring' => 'just exploring',
      _ => 'maintain weight',
    };

    _systemPrompt = '''
You are Asha, a warm, practical AI nutrition assistant inside the Cal Matters app for Indian users. 

KNOW YOUR USER:
- Name: ${profile.name}
- Goal: $goalLabel, ${profile.calorieGoal} kcal/day target, protein target ${profile.proteinGrams}g, carbs ${profile.carbsGrams}g, fat ${profile.fatGrams}g
- Physical: ${profile.age} years, ${profile.sex}, ${profile.weightKg.round()} kg, ${profile.heightCm.round()} cm
- Workouts: ${profile.workoutFreq} times per week

TODAY'S LOG (${DateFormat('EEE d MMM').format(today)}):
- Total: $totalCal kcal, protein ${totalP.toStringAsFixed(0)}g, carbs ${totalC.toStringAsFixed(0)}g, fat ${totalF.toStringAsFixed(0)}g
${foods.isEmpty ? '- Nothing logged yet' : foods}

SPEAK STYLE:
- You are Asha: warm, witty, slightly unhinged, zero filter on FUN (100% filter on medical advice). You speak like a cool, gossipy, food-obsessed bestie — Hinglish mixed with English.
- You NEVER give boring textbook answers. Example: user asks "is rice bad at night?" -> "Arre NO. If rice was a villain, 1 billion Indians were villains since 3000 BC. Log it, walk a bit, done. Bas."
- Use Hinglish: "Arre", "bhai", "chalo", "bas". Emojis sparingly (🔥🦸). Occasional wild facts: "1969 mein Moon pe gye the aur usi saal kisi ne 6th dosa kha liya. Legend."
- Short — 3-5 sentences max. Punchy. Memorable. Never lecture.
- Be specific to INDIAN food (dals, sabzis, rotis, rice, poha/chana). Suggest real Indian substitutes.
- Compare today's log to targets if asked.
- NEVER diagnose, prescribe drugs/supplements, or give medical treatment advice. For anything borderline: say "doctor se poocho, main sirf khaana hoon 😄".
''';

    // Shop-purchased Asha voice (plan §4.4).
    _systemPrompt += _personalitySuffix();
  }

  /// Extra instruction from the user's purchased Asha personality.
  String _personalitySuffix() {
    final inv =
        ShopInventory.fromJson(widget.storage.shopInventoryRaw ?? const {});
    switch (inv.ashaPersonality) {
      case 'asha_coach':
        return '\nVOICE (Coach): Be crisp, direct and goal-focused. Lead with the '
            'single most useful next action, then one line of why. Fewer jokes.';
      case 'asha_friend':
        return '\nVOICE (Friend): Be extra warm and chatty — check in on how the '
            'day is going before the nutrition point. More playful asides.';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add((role: 'user', text: text));
      _controller.clear();
      _sending = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final history = _messages.take(_messages.length - 1).map((m) => {
            'role': m.role,
            'content': m.text,
          }).toList();
      final reply = await OpenAIService().chat(_systemPrompt, history);
      if (!mounted) return;
      setState(() {
        _messages.add((role: 'assistant', text: reply));
        _sending = false;
      });
      // Talking to Asha is a rewarded habit (plan §4.1).
      GamificationController.instance?.recordAshaChat();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Asha couldn\'t reach the server. Check your connection and try again.';
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(8, 6, 20, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: AppColors.ink),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  SizedBox(width: 4),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.protein,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_awesome,
                        size: 17, color: Colors.white),
                  ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asha',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        'Your nutrition assistant',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? _emptyState()
                  : ListView(
                      controller: _scroll,
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        ..._messages.map((m) => _bubble(m)),
                        if (_sending) _TypingBubble(),
                        if (_error != null)
                          Padding(
                            padding: EdgeInsets.all(AppSpace.sm),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.missedRed),
                            ),
                          ),
                      ],
                    ),
            ),
            // Hint chips (only before conversation starts)
            if (_messages.isEmpty) _hintChips(),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.protein.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome,
                  size: 32, color: AppColors.protein),
            ),
            SizedBox(height: 16),
            Text(
              'Namaste! I\'m Asha.',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Column(
                children: [
                  Text(
                    'Wait, first this —',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.muted),
                  ),
                  SizedBox(height: 6),
                  Text(
                    _currentPrompt,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Ask me anything — I read your goal and today\'s log, so the '
              'advice is yours, not copy-paste luck.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: AppType.body, color: AppColors.muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hintChips() {
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 6),
        itemCount: _hints.length,
        itemBuilder: (context, i) => Padding(
          padding: EdgeInsets.only(right: AppSpace.sm),
          child: ActionChip(
            label: Text(
              _hints[i],
              style: TextStyle(
                  fontSize: 12, color: AppColors.ink),
            ),
            backgroundColor: AppColors.card,
            side: BorderSide.none,
            onPressed: () => _send(_hints[i]),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bubble(({String role, String text}) m) {
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpace.sm),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? AppColors.ink : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          m.text,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: isUser ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _inputBar() {
    return ColoredBox(
      color: AppColors.card,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _send(),
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: 'Ask Asha anything…',
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpace.lg, vertical: AppSpace.md),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sheet),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              _sending
                  ? Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.ink),
                      ),
                    )
                  : GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _send();
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.inkButton,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_upward,
                            size: 20, color: Colors.white),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpace.sm),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: AppSpace.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: SizedBox(
          width: 24,
          height: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dot(0.35),
              _dot(0.65),
              _dot(1.0),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _dot(double opacity) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.muted.withValues(alpha: opacity),
          shape: BoxShape.circle,
        ),
      );
}
