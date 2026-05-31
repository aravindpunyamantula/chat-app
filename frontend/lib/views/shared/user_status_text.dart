import 'package:flutter/material.dart';

class UserStatusText extends StatefulWidget {
  final bool isOnline;
  final DateTime? lastSeen;

  final String? typingUserName;

  final TextStyle? onlineStyle;
  final TextStyle? offlineStyle;
  final TextStyle? typingStyle;

  const UserStatusText({
    super.key,
    required this.isOnline,
    this.lastSeen,
    this.typingUserName,
    this.onlineStyle,
    this.offlineStyle,
    this.typingStyle,
  });

  @override
  State<UserStatusText> createState() => _UserStatusTextState();
}

class _UserStatusTextState extends State<UserStatusText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotController;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _dotController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 500),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            setState(() {
              _dotCount = (_dotCount % 3) + 1;
            });
            _dotController.forward(from: 0);
          }
        });

    if (widget.typingUserName != null) {
      _dotController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant UserStatusText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.typingUserName != null && !_dotController.isAnimating) {
      _dotController.forward();
    } else if (widget.typingUserName == null && _dotController.isAnimating) {
      _dotController.stop();
      setState(() => _dotCount = 1);
    }
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'last seen recently';
    final now = DateTime.now();
    final diff = now.difference(lastSeen);

    if (diff.inSeconds < 60) return 'last seen just now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) {
      final h = lastSeen.hour.toString().padLeft(2, '0');
      final m = lastSeen.minute.toString().padLeft(2, '0');
      return 'last seen at $h:$m';
    }
    if (diff.inDays == 1) return 'last seen yesterday';
    return 'last seen ${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultOnlineStyle = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w500,
      color: isDark ? const Color(0xFF22C55E) : const Color(0xFF16A34A),
    );
    final defaultOfflineStyle = TextStyle(
      fontSize: 11.5,
      color: isDark ? Colors.white38 : Colors.black38,
    );
    final defaultTypingStyle = TextStyle(
      fontSize: 11.5,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w500,
      color: isDark ? const Color(0xFF53BDEB) : const Color(0xFF008069),
    );

    if (widget.typingUserName != null) {
      final dots = '.' * _dotCount;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: Text(
          'typing$dots',
          key: ValueKey(dots),
          style: widget.typingStyle ?? defaultTypingStyle,
        ),
      );
    }

    if (widget.isOnline) {
      return Text('Online', style: widget.onlineStyle ?? defaultOnlineStyle);
    }

    return Text(
      _formatLastSeen(widget.lastSeen),
      style: widget.offlineStyle ?? defaultOfflineStyle,
    );
  }
}
