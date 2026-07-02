import 'package:chewie/chewie.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../providers/chat_provider.dart';
import '../../core/network/socket_service.dart';

class WatchTogetherScreen extends StatefulWidget {
  final String conversationId;
  final String? initialVideoUrl;
  final bool isHost;

  const WatchTogetherScreen({
    super.key,
    required this.conversationId,
    this.initialVideoUrl,
    this.isHost = true,
  });

  @override
  State<WatchTogetherScreen> createState() => _WatchTogetherScreenState();
}

class _WatchTogetherScreenState extends State<WatchTogetherScreen> {
  final _urlController = TextEditingController();
  final _imagePicker = ImagePicker();

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  bool _isInitializing = false;
  bool _isUploading = false;
  double _uploadProgress = 0;
  bool _sessionStarted = false;
  String? _loadError;

  bool _suppressSync = false;

  @override
  void initState() {
    super.initState();
    _registerSyncHooks();

    if (widget.initialVideoUrl != null && widget.initialVideoUrl!.isNotEmpty) {
      _urlController.text = widget.initialVideoUrl!;
      _loadVideo(widget.initialVideoUrl!);
    }
  }

  @override
  void dispose() {
    _clearSyncHooks();
    _chewieController?.dispose();
    _videoController?.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _registerSyncHooks() {
    final socket = Provider.of<SocketService>(context, listen: false);

    socket.onWatchSync = (action, position) {
      if (_suppressSync || _videoController == null) return;
      _suppressSync = true;

      final target = Duration(seconds: position.toInt());
      switch (action) {
        case 'play':
          _videoController!.seekTo(target).then((_) {
            _videoController!.play();
            _suppressSync = false;
          });
        case 'pause':
          _videoController!.seekTo(target).then((_) {
            _videoController!.pause();
            _suppressSync = false;
          });
        case 'seek':
          _videoController!.seekTo(target).then((_) => _suppressSync = false);
      }
    };

    socket.onWatchSessionEnded = (byId, byName) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$byName ended the session.')),
      );
      Navigator.of(context).pop();
    };

    socket.onWatchViewerJoined = (viewerId, viewerName) {
      if (!mounted || !widget.isHost || _videoController == null) return;
      final pos = _videoController!.value.position.inSeconds.toDouble();
      final isPlaying = _videoController!.value.isPlaying;
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.sendWatchSync(isPlaying ? 'play' : 'pause', pos);
    };
  }

  void _clearSyncHooks() {
    final socket = Provider.of<SocketService>(context, listen: false);
    socket.onWatchSync = null;
    socket.onWatchSessionEnded = null;
    socket.onWatchViewerJoined = null;
  }

  Future<void> _loadVideo(String url) async {
    setState(() {
      _isInitializing = true;
      _loadError = null;
    });

    try {
      await _videoController?.dispose();
      _chewieController?.dispose();

      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();

      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: widget.isHost,
      );

      _videoController = controller;
      _chewieController = chewie;

      if (widget.isHost) {
        controller.addListener(_onVideoStateChanged);
      }

      if (mounted) setState(() => _isInitializing = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _loadError = 'Could not load video. Check the URL and try again.';
        });
      }
    }
  }

  DateTime _lastSyncSent = DateTime.fromMillisecondsSinceEpoch(0);

  void _onVideoStateChanged() {
    if (_suppressSync || _videoController == null) return;

    final now = DateTime.now();
    if (now.difference(_lastSyncSent).inMilliseconds < 500) return;
    _lastSyncSent = now;

    final pos = _videoController!.value.position.inSeconds.toDouble();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (_videoController!.value.isPlaying) {
      chatProvider.sendWatchSync('play', pos);
    } else {
      chatProvider.sendWatchSync('pause', pos);
    }
  }

  void _startSession() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.startWatchSession(url);

    setState(() => _sessionStarted = true);
    _loadVideo(url);
  }

  void _endSession() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.endWatchSession();
    Navigator.of(context).pop();
  }

  Future<void> _pickAndUploadLocalVideo() async {
    final XFile? picked = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final apiClient = Provider.of<ApiClient>(context, listen: false);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          picked.path,
          filename: picked.name,
        ),
      });

      final response = await apiClient.dio.post(
        ApiEndpoints.upload,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );

      final relativePath = response.data['fileUrl'] as String;
      final fullUrl = '${ApiEndpoints.mediaBaseUrl}$relativePath';

      if (mounted) {
        setState(() {
          _isUploading = false;
          _urlController.text = fullUrl;
        });
        _startSession();
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    // If partner started a session and we're the viewer, auto-load
    if (!_sessionStarted &&
        !widget.isHost &&
        chatProvider.isWatchSessionActive &&
        chatProvider.watchVideoUrl != null &&
        _videoController == null &&
        !_isInitializing) {
      _sessionStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _urlController.text = chatProvider.watchVideoUrl!;
        _loadVideo(chatProvider.watchVideoUrl!);
        final chatProv = Provider.of<ChatProvider>(context, listen: false);
        chatProv.joinWatchSession(chatProvider.watchVideoUrl!);
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Watch Together'),
        actions: [
          if (_sessionStarted)
            TextButton.icon(
              onPressed: _endSession,
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
              label: const Text('End', style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Upload progress bar
          if (_isUploading)
            Container(
              color: const Color(0xFF1A1A1A),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.upload_rounded, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Uploading video… ${(_uploadProgress * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary),
                  ),
                ],
              ),
            ),

          // ── Video player ──────────────────────────────────────────────────
          Expanded(
            child: _isInitializing
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 12),
                        Text('Loading video…',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  )
                : _loadError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.redAccent, size: 40),
                              const SizedBox(height: 12),
                              Text(_loadError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: () => setState(() => _loadError = null),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white),
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _chewieController != null
                        ? Chewie(controller: _chewieController!)
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.movie_outlined,
                                    size: 64,
                                    color: Colors.white.withValues(alpha: 0.3)),
                                const SizedBox(height: 16),
                                Text(
                                  widget.isHost
                                      ? 'Paste a video URL or cast from your device'
                                      : 'Waiting for your partner to start a session…',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
          ),

          // ── Host controls (before session starts) ────────────────────────
          if (widget.isHost && !_sessionStarted && !_isUploading)
            Container(
              color: const Color(0xFF1A1A1A),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VIDEO SOURCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Cast from device button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickAndUploadLocalVideo,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.phone_android_rounded, size: 18),
                      label: const Text('Cast video from your device'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or paste a URL',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 12)),
                      ),
                      Expanded(
                          child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'https://example.com/movie.mp4',
                            hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _startSession,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Start'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ── Viewer waiting banner ─────────────────────────────────────────
          if (!widget.isHost && !_sessionStarted)
            Container(
              width: double.infinity,
              color: const Color(0xFF1A1A1A),
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Your partner will start the session. Stay tuned!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
