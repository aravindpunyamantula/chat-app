import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/socket_service.dart';
import '../../providers/chat_provider.dart';

class ConnectionStatusBanner extends StatefulWidget {
  const ConnectionStatusBanner({super.key});

  @override
  State<ConnectionStatusBanner> createState() => _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnim;

  SocketConnectionState? _lastState;
  bool _showSuccess = false;
  Timer? _successTimer;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _slideController.dispose();
    _successTimer?.cancel();
    super.dispose();
  }

  void _triggerSuccess() {
    setState(() => _showSuccess = true);
    _slideController.forward(from: 0);
    _successTimer?.cancel();
    _successTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        _slideController.reverse().then((_) {
          if (mounted) setState(() => _showSuccess = false);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final state = chatProvider.connectionState;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state == SocketConnectionState.connected &&
        (_lastState == SocketConnectionState.connecting ||
            _lastState == SocketConnectionState.disconnected)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerSuccess());
    }
    _lastState = state;

    final bool isDisconnected = state == SocketConnectionState.disconnected;
    final bool isConnecting = state == SocketConnectionState.connecting;
    final bool showPersistentBanner = isDisconnected || isConnecting;

    if (!showPersistentBanner && !_showSuccess) {
      return const SizedBox.shrink();
    }

    late Color bannerColor;
    late Widget leadingWidget;
    late String label;

    if (_showSuccess && !showPersistentBanner) {
      bannerColor = const Color(0xFF16A34A);
      label = 'Connected';
      leadingWidget = const Icon(
        Icons.check_circle_rounded,
        size: 13,
        color: Colors.white,
      );
    } else if (isConnecting) {
      bannerColor = isDark ? const Color(0xFF92400E) : const Color(0xFFB45309);
      label = 'Connecting…';
      leadingWidget = const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    } else {
      bannerColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFB91C1C);
      label = 'No connection — messages may not send';
      leadingWidget = const Icon(
        Icons.wifi_off_rounded,
        size: 13,
        color: Colors.white,
      );
    }

    final Widget bannerContent = Container(
      height: 34,
      width: double.infinity,
      color: bannerColor,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leadingWidget,
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );

    if (_showSuccess && !showPersistentBanner) {
      return SlideTransition(position: _slideAnim, child: bannerContent);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) =>
          SizeTransition(sizeFactor: anim, axis: Axis.vertical, child: child),
      child: showPersistentBanner
          ? KeyedSubtree(key: ValueKey(state), child: bannerContent)
          : const SizedBox.shrink(),
    );
  }
}
