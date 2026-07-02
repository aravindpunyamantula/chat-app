import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../core/network/socket_service.dart';
import '../../providers/chat_provider.dart';

/// One user casts their screen (e.g. Netflix/Hotstar playing on their device),
/// the partner watches the live stream inside the app — no shared login needed.
///
/// Signaling flow:
///   Host → watch_session_start (url="cast:") → partner notified
///   Viewer joins → watch_session_join
///   Host receives viewer_joined → starts screen capture → webrtc_offer
///   Viewer → webrtc_answer
///   ICE exchange → P2P connected
class CastScreen extends StatefulWidget {
  final String conversationId;
  final bool isHost;

  const CastScreen({
    super.key,
    required this.conversationId,
    required this.isHost,
  });

  @override
  State<CastScreen> createState() => _CastScreenState();
}

class _CastScreenState extends State<CastScreen> {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  _CastStatus _status = _CastStatus.waiting;
  String _statusLabel = '';

  static const _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    _remoteRenderer.initialize();
    _registerHooks();

    if (widget.isHost) {
      _statusLabel = 'Waiting for partner to join...\n(They will see a notification in chat)';
      // Partner is notified via watch_session_started → they open CastScreen as viewer
      // → they emit watch_session_join → we get viewer_joined → then we start capture
    } else {
      // Viewer: tell host we're here, then wait for WebRTC offer
      _statusLabel = "Connecting to host's screen...";
      _status = _CastStatus.waiting;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        chatProvider.joinWatchSession('cast:');
        // Offer will arrive via onWebRtcOffer hook
      });
    }
  }

  @override
  void dispose() {
    _clearHooks();
    _localStream?.getTracks().forEach((t) => t.stop());
    _remoteStream?.getTracks().forEach((t) => t.stop());
    _pc?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  // ── Socket hooks ──────────────────────────────────────────────────────────

  void _registerHooks() {
    final socket = Provider.of<SocketService>(context, listen: false);

    // Host: viewer joined → start capture & send offer
    socket.onWatchViewerJoined = (viewerId, viewerName) {
      if (!widget.isHost || !mounted) return;
      setState(() {
        _statusLabel = '$viewerName joined — starting screen capture...';
        _status = _CastStatus.starting;
      });
      _startCapture();
    };

    // Viewer: receive offer from host
    socket.onWebRtcOffer = (sdp, fromId) async {
      if (widget.isHost || !mounted) return;
      await _handleOffer(sdp);
    };

    // Host: receive answer from viewer
    socket.onWebRtcAnswer = (sdp, fromId) async {
      if (!widget.isHost || !mounted) return;
      await _pc?.setRemoteDescription(
        RTCSessionDescription(sdp['sdp'] as String, sdp['type'] as String),
      );
    };

    // Both: exchange ICE candidates
    socket.onWebRtcIceCandidate = (candidate, fromId) async {
      if (!mounted) return;
      await _pc?.addCandidate(RTCIceCandidate(
        candidate['candidate'] as String?,
        candidate['sdpMid'] as String?,
        candidate['sdpMLineIndex'] as int?,
      ));
    };

    // Session ended by partner
    socket.onWatchSessionEnded = (byId, byName) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$byName ended the cast.')),
      );
    };
  }

  void _clearHooks() {
    final socket = Provider.of<SocketService>(context, listen: false);
    socket.onWatchViewerJoined = null;
    socket.onWebRtcOffer = null;
    socket.onWebRtcAnswer = null;
    socket.onWebRtcIceCandidate = null;
    socket.onWatchSessionEnded = null;
  }

  // ── Host: screen capture → offer ─────────────────────────────────────────

  Future<void> _startCapture() async {
    try {
      // On Android this triggers the "Start recording?" system dialog
      _localStream = await navigator.mediaDevices.getDisplayMedia({
        'video': {'frameRate': 30, 'width': 1280, 'height': 720},
        'audio': true,
      });

      _localRenderer.srcObject = _localStream;

      _pc = await createPeerConnection(_rtcConfig);
      _setupPCHandlers();

      for (final track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }

      final offer = await _pc!.createOffer({'offerToReceiveVideo': 0});
      await _pc!.setLocalDescription(offer);

      if (!mounted) return;
      final socket = Provider.of<SocketService>(context, listen: false);
      socket.sendWebRtcOffer(widget.conversationId, {
        'type': offer.type,
        'sdp': offer.sdp,
      });

      if (mounted) {
        setState(() {
          _status = _CastStatus.live;
          _statusLabel = 'LIVE';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = _CastStatus.error;
          _statusLabel = 'Screen capture failed. Make sure you allow recording when prompted.';
        });
      }
    }
  }

  // ── Viewer: answer → receive stream ──────────────────────────────────────

  Future<void> _handleOffer(Map<String, dynamic> sdp) async {
    if (!mounted) return;
    setState(() {
      _status = _CastStatus.starting;
      _statusLabel = 'Host is sharing screen...';
    });

    try {
      _pc = await createPeerConnection(_rtcConfig);
      _setupPCHandlers();

      await _pc!.setRemoteDescription(
        RTCSessionDescription(sdp['sdp'] as String, sdp['type'] as String),
      );

      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);

      if (!mounted) return;
      final socket = Provider.of<SocketService>(context, listen: false);
      socket.sendWebRtcAnswer(widget.conversationId, {
        'type': answer.type,
        'sdp': answer.sdp,
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = _CastStatus.error;
          _statusLabel = 'Connection failed: $e';
        });
      }
    }
  }

  // ── Shared: peer connection event handlers ────────────────────────────────

  void _setupPCHandlers() {
    _pc!.onIceCandidate = (c) {
      if (c.candidate == null) return;
      final socket = Provider.of<SocketService>(context, listen: false);
      socket.sendWebRtcIceCandidate(widget.conversationId, {
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };

    _pc!.onConnectionState = (state) {
      if (!mounted) return;
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          setState(() {
            _status = _CastStatus.live;
            _statusLabel = 'LIVE';
          });
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          setState(() {
            _status = _CastStatus.error;
            _statusLabel = 'Connection failed. Check your network.';
          });
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          setState(() {
            _status = _CastStatus.waiting;
            _statusLabel = 'Reconnecting...';
          });
        default:
          break;
      }
    };

    // Viewer receives the host's video track here
    _pc!.onTrack = (event) {
      if (!mounted || event.streams.isEmpty) return;
      setState(() {
        _remoteStream = event.streams.first;
        _remoteRenderer.srcObject = _remoteStream;
        _status = _CastStatus.live;
        _statusLabel = 'LIVE';
      });
    };
  }

  // ── Stop ──────────────────────────────────────────────────────────────────

  void _stopCast() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.endWatchSession();
    Navigator.of(context).pop();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLive = _status == _CastStatus.live;
    final isError = _status == _CastStatus.error;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.isHost ? 'Casting Your Screen' : 'Live from Partner',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          if (widget.isHost)
            TextButton.icon(
              onPressed: _stopCast,
              icon: const Icon(Icons.stop_circle_outlined,
                  color: Colors.redAccent, size: 18),
              label: const Text('Stop cast',
                  style: TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── Viewer: full-screen remote video ─────────────────────────────
          if (!widget.isHost && _remoteStream != null)
            SizedBox.expand(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              ),
            ),

          // ── Host: small preview of own screen ────────────────────────────
          if (widget.isHost && _localStream != null && isLive)
            Positioned(
              bottom: 96,
              right: 16,
              width: 140,
              height: 80,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: Colors.black,
                  child: RTCVideoView(
                    _localRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          // ── Status overlay (waiting / starting / error) ───────────────────
          if (!isLive || (!widget.isHost && _remoteStream == null))
            Container(
              color: Colors.black87,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_status == _CastStatus.starting)
                        const CircularProgressIndicator(color: Colors.white)
                      else
                        Icon(
                          isError
                              ? Icons.error_outline_rounded
                              : (widget.isHost
                                  ? Icons.cast_rounded
                                  : Icons.cast_connected_rounded),
                          size: 64,
                          color: isError
                              ? Colors.redAccent
                              : Colors.white38,
                        ),
                      const SizedBox(height: 20),
                      Text(
                        _statusLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isError ? Colors.redAccent : Colors.white70,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      if (widget.isHost && !isError)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text(
                            'Open Netflix, Hotstar, or any streaming app on your device.\n'
                            'Your partner will see whatever is on your screen.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // ── LIVE badge ───────────────────────────────────────────────────
          if (isLive)
            Positioned(
              top: 96,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 7, color: Colors.white),
                    SizedBox(width: 5),
                    Text('LIVE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _CastStatus { waiting, starting, live, error }
