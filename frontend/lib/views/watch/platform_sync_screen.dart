import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/network/socket_service.dart';
import '../../providers/chat_provider.dart';

class PlatformSyncScreen extends StatefulWidget {
  final String conversationId;

  const PlatformSyncScreen({super.key, required this.conversationId});

  @override
  State<PlatformSyncScreen> createState() => _PlatformSyncScreenState();
}

class _PlatformSyncScreenState extends State<PlatformSyncScreen> {
  // Local timer state
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  Timer? _ticker;

  // Partner state
  String? _partnerStatus; // e.g. "Paused at 14:32"
  bool _partnerInSync = false;

  // Selected platform (visual only)
  String _selectedPlatform = 'Netflix';

  static const _platforms = ['Netflix', 'Prime', 'Hotstar', 'Disney+', 'Apple TV+', 'YouTube'];

  @override
  void initState() {
    super.initState();
    _registerSyncHooks();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clearSyncHooks();
    super.dispose();
  }

  void _registerSyncHooks() {
    final socket = Provider.of<SocketService>(context, listen: false);
    socket.onWatchSync = (action, position) {
      final partnerPos = Duration(seconds: position.toInt());
      setState(() {
        switch (action) {
          case 'play':
            _position = partnerPos;
            _isPlaying = true;
            _partnerStatus = 'Playing from ${_formatDuration(partnerPos)}';
            break;
          case 'pause':
            _position = partnerPos;
            _isPlaying = false;
            _partnerStatus = 'Paused at ${_formatDuration(partnerPos)}';
            break;
          case 'seek':
            _position = partnerPos;
            _partnerStatus = 'Jumped to ${_formatDuration(partnerPos)}';
            break;
        }
        _partnerInSync = (_position - partnerPos).abs() < const Duration(seconds: 3);
      });
    };
  }

  void _clearSyncHooks() {
    final socket = Provider.of<SocketService>(context, listen: false);
    socket.onWatchSync = null;
  }

  void _play() {
    HapticFeedback.mediumImpact();
    setState(() => _isPlaying = true);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _position += const Duration(seconds: 1));
    });
    _emitSync('play');
  }

  void _pause() {
    HapticFeedback.mediumImpact();
    setState(() => _isPlaying = false);
    _ticker?.cancel();
    _emitSync('pause');
  }

  void _seek(int deltaSeconds) {
    HapticFeedback.selectionClick();
    final newPos = _position + Duration(seconds: deltaSeconds);
    setState(() {
      _position = newPos.isNegative ? Duration.zero : newPos;
    });
    _emitSync('seek');
  }

  void _syncNow() {
    HapticFeedback.lightImpact();
    _emitSync(_isPlaying ? 'play' : 'pause');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sync signal sent to partner!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _emitSync(String action) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.sendWatchSync(action, _position.inSeconds.toDouble());
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        foregroundColor: Colors.white,
        title: const Text('Platform Sync'),
        actions: [
          TextButton.icon(
            onPressed: _syncNow,
            icon: const Icon(Icons.sync_rounded, color: Colors.greenAccent, size: 18),
            label: const Text('Sync now',
                style: TextStyle(color: Colors.greenAccent, fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Platform selector
          Container(
            color: const Color(0xFF161616),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WATCHING ON',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.4))),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _platforms.map((p) {
                      final selected = p == _selectedPlatform;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedPlatform = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? theme.colorScheme.primary
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: selected
                                ? null
                                : Border.all(
                                    color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            p,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.white60,
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const Expanded(child: SizedBox()),

          // Timer display
          Column(
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w200,
                  letterSpacing: -2,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isPlaying
                        ? Icons.play_circle_filled_rounded
                        : Icons.pause_circle_filled_rounded,
                    size: 14,
                    color: _isPlaying ? Colors.greenAccent : Colors.white38,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isPlaying ? 'Playing' : 'Paused',
                    style: TextStyle(
                      color: _isPlaying ? Colors.greenAccent : Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Partner status
          if (_partnerStatus != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _partnerInSync
                        ? Colors.greenAccent.withValues(alpha: 0.4)
                        : Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _partnerInSync
                        ? Icons.check_circle_outline_rounded
                        : Icons.warning_amber_rounded,
                    size: 15,
                    color: _partnerInSync ? Colors.greenAccent : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Partner: $_partnerStatus',
                      style: TextStyle(
                        color: _partnerInSync ? Colors.greenAccent : Colors.orange,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 36),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlButton(
                icon: Icons.replay_10_rounded,
                label: '-10s',
                onTap: () => _seek(-10),
              ),
              const SizedBox(width: 16),
              _ControlButton(
                icon: Icons.replay_30_rounded,
                label: '-30s',
                onTap: () => _seek(-30),
                size: 36,
              ),
              const SizedBox(width: 20),

              // Play / Pause main button
              GestureDetector(
                onTap: _isPlaying ? _pause : _play,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),

              const SizedBox(width: 20),
              _ControlButton(
                icon: Icons.forward_30_rounded,
                label: '+30s',
                onTap: () => _seek(30),
                size: 36,
              ),
              const SizedBox(width: 16),
              _ControlButton(
                icon: Icons.forward_10_rounded,
                label: '+10s',
                onTap: () => _seek(10),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Instructions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Both of you open $_selectedPlatform on your device and start the same content. Use these controls together — pressing Play/Pause sends a sync signal to your partner.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: size),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}
