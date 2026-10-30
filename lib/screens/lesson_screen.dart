import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../models/lesson.dart';
import '../models/health_path.dart';
import '../services/gamification_controller.dart';
import 'capture_screen.dart';


class LessonScreen extends StatefulWidget {
  final Lesson lesson;
  final PathNode node;
  final VoidCallback? onComplete;

  const LessonScreen({
    super.key,
    required this.lesson,
    required this.node,
    this.onComplete,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> with TickerProviderStateMixin {
  int _currentStep = 0;
  int _hearts = 5;
  late AnimationController _progressController;
  late AnimationController _buttonController;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _updateProgress();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  void _updateProgress() {
    final progress = (_currentStep + 1) / widget.lesson.steps.length;
    _progressController.animateTo(progress);
  }

  void _nextStep() {
    if (_isAnimating) return;
    _isAnimating = true;
    
    HapticFeedback.lightImpact();
    
    if (_currentStep < widget.lesson.steps.length - 1) {
      setState(() {
        _currentStep++;
        _updateProgress();
      });
      _isAnimating = false;
    } else {
      _completeLesson();
    }
  }

  void _completeLesson() async {
    HapticFeedback.heavyImpact();

    // Hearts refill on completion. The reward + journey progression are owned
    // by the caller: onComplete goes through the gamified event path (award →
    // celebrate → persist → bump) and then marks the node complete.
    setState(() {
      _hearts = 5;
    });

    await Future.delayed(const Duration(milliseconds: 2500));

    if (mounted) {
      widget.onComplete?.call();
      Navigator.of(context).pop(true);
    }
  }

  void _handleAction() async {
    final step = widget.lesson.steps[_currentStep];
    HapticFeedback.mediumImpact();
    
    bool completed = false;
    
    switch (step.actionType) {
      case 'meal':
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => CaptureScreen(storage: GamificationController.instance!.storage),
          ),
        );
        completed = result == true;
        break;
      case 'water':
        await GamificationController.instance!.storage.addWater(250);
        completed = true;
        break;
      case 'exercise':
        // Could open exercise sheet
        completed = true;
        break;
      case 'weight':
        completed = true;
        break;
      default:
        completed = true;
    }
    
    if (completed) {
      _nextStep();
    } else {
      // Lost a heart for not completing
      setState(() {
        _hearts--;
      });
      if (_hearts <= 0) {
        _showNoHeartsDialog();
      }
    }
  }

  void _showNoHeartsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Out of hearts!'),
        content: const Text('Take a break and come back later, or wait for hearts to refill.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.lesson.steps[_currentStep];
    final isLastStep = _currentStep == widget.lesson.steps.length - 1;
    final isActionStep = step.type == LessonStepType.action;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header with progress and hearts
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppColors.muted),
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _progressController.value,
                            backgroundColor: AppColors.divider,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF58CC02),
                            ),
                            minHeight: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      const Text('❤️', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 4),
                      Text(
                        '$_hearts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      step.icon ?? widget.lesson.icon,
                      style: const TextStyle(fontSize: 80),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      step.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      step.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isActionStep ? _handleAction : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF58CC02),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    shadowColor: const Color(0xFF46A302),
                  ),
                  child: Text(
                    isActionStep 
                        ? (step.actionType == 'meal' ? 'LOG MEAL' : 'DO IT')
                        : (isLastStep ? 'COMPLETE' : 'CONTINUE'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
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
