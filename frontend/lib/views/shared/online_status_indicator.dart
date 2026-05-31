import 'package:flutter/material.dart';

class OnlineStatusIndicator extends StatefulWidget {
  final bool isOnline;

  final double size;

  final Color borderColor;

  const OnlineStatusIndicator({
    super.key,
    required this.isOnline,
    this.size = 12.0,
    this.borderColor = Colors.white,
  });

  @override
  State<OnlineStatusIndicator> createState() => _OnlineStatusIndicatorState();
}

class _OnlineStatusIndicatorState extends State<OnlineStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOnline) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF9E9E9E),
            shape: BoxShape.circle,
            border: Border.all(color: widget.borderColor, width: 1.8),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Container(
              width: widget.size * 0.72,
              height: widget.size * 0.72,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: widget.borderColor, width: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
