import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/health_path.dart';
import '../theme/app_colors.dart';

class PathNodeWidget extends StatefulWidget {
  final PathNode node;
  final PathNodeState state;
  final VoidCallback? onTap;
  final bool isOffset;

  const PathNodeWidget({
    super.key,
    required this.node,
    required this.state,
    this.onTap,
    this.isOffset = false,
  });

  @override
  State<PathNodeWidget> createState() => _PathNodeWidgetState();
}

class _PathNodeWidgetState extends State<PathNodeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.state == PathNodeState.current) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PathNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == PathNodeState.current && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (widget.state != PathNodeState.current && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getNodeColor() {
    switch (widget.state) {
      case PathNodeState.completed:
        return const Color(0xFF58CC02); // Duolingo green
      case PathNodeState.current:
        return const Color(0xFFFFC800); // Duolingo yellow/gold
      case PathNodeState.locked:
        return const Color(0xFFE5E5E5);
    }
  }

  Color _getBorderColor() {
    switch (widget.state) {
      case PathNodeState.completed:
        return const Color(0xFF46A302);
      case PathNodeState.current:
        return const Color(0xFFE5A000);
      case PathNodeState.locked:
        return const Color(0xFFCECECE);
    }
  }

  Widget _buildIcon() {
    switch (widget.state) {
      case PathNodeState.completed:
        return const Icon(
          Icons.check,
          color: Colors.white,
          size: 32,
        );
      case PathNodeState.current:
      case PathNodeState.locked:
        return Text(
          widget.node.icon,
          style: TextStyle(
            fontSize: 28,
            color: widget.state == PathNodeState.locked 
                ? AppColors.muted 
                : Colors.white,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodeColor = _getNodeColor();
    final borderColor = _getBorderColor();
    final canTap = widget.state == PathNodeState.current;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = widget.state == PathNodeState.current 
            ? _pulseAnimation.value 
            : 1.0;
        return Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: canTap && widget.onTap != null
                    ? () {
                        HapticFeedback.mediumImpact();
                        widget.onTap!();
                      }
                    : null,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: nodeColor,
                    border: Border.all(
                      color: borderColor,
                      width: 4,
                    ),
                    boxShadow: widget.state == PathNodeState.current
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFC800).withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: _buildIcon(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (widget.state == PathNodeState.current)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF58CC02),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'START',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              else if (widget.state == PathNodeState.completed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+${widget.node.xpReward}',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'XP',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
