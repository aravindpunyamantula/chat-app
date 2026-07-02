import 'dart:async';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../data/models/message_model.dart';
import '../shared/connection_status_banner.dart';
import '../shared/user_status_text.dart';
import '../watch/cast_screen.dart';
import '../watch/platform_sync_screen.dart';
import '../watch/watch_together_screen.dart';
import 'widgets/message_bubble.dart';

class _ChatItem {
  final String type; // 'date' or 'message'
  final dynamic data;
  _ChatItem(this.type, this.data);
}

class ChatRoomView extends StatefulWidget {
  final String conversationTitle;

  const ChatRoomView({super.key, required this.conversationTitle});

  @override
  State<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<ChatRoomView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  MessageModel? _replyingTo;
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _showEmojiPicker = false;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _toggleEmojiPicker() {
    setState(() => _showEmojiPicker = !_showEmojiPicker);
    if (_showEmojiPicker) FocusScope.of(context).unfocus();
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final controller = _messageController;
    final text = controller.text;
    final selection = controller.selection;
    final newText = text.replaceRange(
      selection.start.clamp(0, text.length),
      selection.end.clamp(0, text.length),
      emoji.emoji,
    );
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start.clamp(0, text.length) + emoji.emoji.length,
      ),
    );
  }

  Future<void> _pickAndSendImage() async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final apiClient = Provider.of<ApiClient>(context, listen: false);

    await chatProvider.sendMediaMessage(apiClient, picked.path, 'image/jpeg');
  }

  Future<void> _pickAndSendVideo() async {
    final XFile? picked = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final apiClient = Provider.of<ApiClient>(context, listen: false);

    await chatProvider.sendMediaMessage(apiClient, picked.path, 'video/mp4');
  }

  void _openWatchMenu() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final conversationId = chatProvider.activeConversationId ?? '';

    // Partner started a screen cast → open as viewer
    if (chatProvider.isWatchSessionActive &&
        !chatProvider.isWatchHost &&
        chatProvider.watchVideoUrl == 'cast:') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CastScreen(conversationId: conversationId, isHost: false),
      ));
      return;
    }

    // Partner started a video stream → open as viewer
    if (chatProvider.isWatchSessionActive && !chatProvider.isWatchHost) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WatchTogetherScreen(
          conversationId: conversationId,
          initialVideoUrl: chatProvider.watchVideoUrl,
          isHost: false,
        ),
      ));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('Watch Together',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: theme.colorScheme.onSurface)),
              ),
              // Cast Screen — streams host's device screen (Netflix, Hotstar, etc.)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.withValues(alpha: 0.15),
                  child: const Icon(Icons.cast_rounded, color: Colors.red),
                ),
                title: const Text('Cast my screen'),
                subtitle: const Text(
                    'Stream what\'s on your screen — Netflix, Hotstar, any app'),
                onTap: () {
                  Navigator.pop(ctx);
                  // Notify partner then open host cast screen
                  chatProvider.startWatchSession('cast:');
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        CastScreen(conversationId: conversationId, isHost: true),
                  ));
                },
              ),
              // Watch Together — direct video URL or upload local file
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.play_circle_outline_rounded,
                      color: theme.colorScheme.primary),
                ),
                title: const Text('Stream a video'),
                subtitle: const Text('Cast a local file or stream from a URL'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => WatchTogetherScreen(
                      conversationId: conversationId,
                      isHost: true,
                    ),
                  ));
                },
              ),
              // Platform Sync — sync timer for Netflix/Prime/Hotstar
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Icon(Icons.sync_rounded,
                      color: theme.colorScheme.secondary),
                ),
                title: const Text('Platform Sync'),
                subtitle: const Text(
                    'Stay in sync while watching Netflix, Prime, Hotstar...'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        PlatformSyncScreen(conversationId: conversationId),
                  ));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.loadMoreMessages();
    }
  }

  void _onTextChanged() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final text = _messageController.text.trim();

    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      chatProvider.sendTypingStatus(true);
    } else if (text.isEmpty && _isTyping) {
      _isTyping = false;
      chatProvider.sendTypingStatus(false);
    }

    _typingTimer?.cancel();
    if (text.isNotEmpty) {
      _typingTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted && _isTyping) {
          setState(() {
            _isTyping = false;
          });
          chatProvider.sendTypingStatus(false);
        }
      });
    }
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _messageController.clear();

    _isTyping = false;
    _typingTimer?.cancel();
    chatProvider.sendTypingStatus(false);

    String finalPayload = content;
    if (_replyingTo != null) {
      final cleanQuoteText = _replyingTo!.content.replaceAll('\n', ' ');
      finalPayload =
          '"> [${_replyingTo!.sender.name}] $cleanQuoteText"\n\n$content';

      setState(() {
        _replyingTo = null;
      });
    }

    await chatProvider.sendRealtimeMessage(finalPayload);
  }

  String _formatDividerDate(DateTime dt) {
    final now = DateTime.now();
    if (now.year == dt.year && now.month == dt.month && now.day == dt.day) {
      return 'TODAY';
    } else if (now.year == dt.year &&
        now.month == dt.month &&
        now.day - dt.day == 1) {
      return 'YESTERDAY';
    } else {
      final List<String> months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final currentUserId = authProvider.currentUser?.id;

    chatProvider.setCurrentUserId(currentUserId);

    final theme = Theme.of(context);

    final Color bgWallpaperColor = theme.colorScheme.surface;
    final Color bottomInputBarColor = theme.colorScheme.surfaceContainerLow;
    final Color sendButtonColor = theme.colorScheme.primary;

    final messages = chatProvider.activeMessages;
    final List<_ChatItem> chatItems = [];

    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];

      if (i == 0) {
        chatItems.add(_ChatItem('date', msg.createdAt));
      } else {
        final prevMsg = messages[i - 1];
        if (msg.createdAt.year != prevMsg.createdAt.year ||
            msg.createdAt.month != prevMsg.createdAt.month ||
            msg.createdAt.day != prevMsg.createdAt.day) {
          chatItems.add(_ChatItem('date', msg.createdAt));
        }
      }

      bool isConsecutive = false;
      if (i > 0) {
        final prevMsg = messages[i - 1];
        final bool dayChanged =
            msg.createdAt.year != prevMsg.createdAt.year ||
            msg.createdAt.month != prevMsg.createdAt.month ||
            msg.createdAt.day != prevMsg.createdAt.day;

        if (!dayChanged && prevMsg.sender.id == msg.sender.id) {
          isConsecutive = true;
        }
      }

      chatItems.add(
        _ChatItem('message', {'message': msg, 'isConsecutive': isConsecutive}),
      );
    }

    final isOtherTyping = chatProvider.typingUserName != null;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          chatProvider.deselectConversation();
        }
      },
      child: Scaffold(
        backgroundColor: bgWallpaperColor,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surfaceContainerLow,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: theme.colorScheme.onSurface,
                  ),
                  onPressed: () {
                    chatProvider.deselectConversation();
                    Navigator.of(context).pop();
                  },
                )
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.conversationTitle,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              UserStatusText(
                isOnline: true,
                typingUserName: chatProvider.typingUserName,
              ),
            ],
          ),
          actions: [
            // Watch Together button — pulses when a session is active
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: 'Watch Together',
                  icon: Icon(
                    Icons.movie_outlined,
                    color: chatProvider.isWatchSessionActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  onPressed: _openWatchMenu,
                ),
                if (chatProvider.isWatchSessionActive)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
              const ConnectionStatusBanner(),

              // Incoming cast notification banner
              if (chatProvider.incomingCastHostName != null)
                _IncomingCastBanner(
                  hostName: chatProvider.incomingCastHostName!,
                  onJoin: _openWatchMenu,
                ),

              Expanded(
                child: chatProvider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : chatItems.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 28,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Messages are secured on server.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Start the conversation!',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        addSemanticIndexes: false,
                        itemCount:
                            chatItems.length +
                            (chatProvider.hasMoreMessages ? 1 : 0) +
                            (isOtherTyping ? 1 : 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        itemBuilder: (context, index) {
                          if (isOtherTyping && index == 0) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(
                                  left: 12,
                                  top: 4,
                                  bottom: 4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                    topLeft: Radius.zero,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${chatProvider.typingUserName} is typing',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontStyle: FontStyle.italic,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              theme.colorScheme.primary,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final actualIndex = isOtherTyping ? index - 1 : index;

                          if (chatProvider.hasMoreMessages &&
                              actualIndex == chatItems.length) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: chatProvider.isLoadingMore
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'Scroll up to load older messages',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                              ),
                            );
                          }

                          final item =
                              chatItems[chatItems.length - 1 - actualIndex];

                          if (item.type == 'date') {
                            final DateTime dt = item.data as DateTime;
                            return Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _formatDividerDate(dt),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            );
                          }

                          final Map<String, dynamic> msgData =
                              item.data as Map<String, dynamic>;
                          final MessageModel msg =
                              msgData['message'] as MessageModel;
                          final bool isConsecutive =
                              msgData['isConsecutive'] as bool;
                          final bool isMe =
                              (msg.sender.id.isNotEmpty &&
                                  msg.sender.id == currentUserId) ||
                              (msg.sender.email.isNotEmpty &&
                                  msg.sender.email ==
                                      authProvider.currentUser?.email);

                          return MessageBubble(
                            key: ValueKey(msg.id),
                            message: msg,
                            isMe: isMe,
                            isConsecutive: isConsecutive,
                            onReply: () {
                              setState(() {
                                _replyingTo = msg;
                              });

                              FocusScope.of(context).requestFocus();
                            },
                          );
                        },
                      ),
              ),

              if (_replyingTo != null)
                Container(
                  color: bottomInputBarColor,
                  padding: const EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 8,
                    bottom: 4,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                bottomLeft: Radius.circular(8),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _replyingTo!.sender.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _replyingTo!.content,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                _replyingTo = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Input bar ──────────────────────────────────────────────
              Container(
                color: bottomInputBarColor,
                padding: const EdgeInsets.only(
                  left: 8.0,
                  right: 8.0,
                  bottom: 8.0,
                  top: 4.0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                  child: Row(
                    children: [
                      // Emoji toggle
                      IconButton(
                        tooltip: 'Emoji',
                        icon: Icon(
                          _showEmojiPicker
                              ? Icons.keyboard_rounded
                              : Icons.emoji_emotions_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: _toggleEmojiPicker,
                      ),
                      // Image / video picker
                      IconButton(
                        tooltip: 'Attach image or video',
                        icon: Icon(
                          Icons.attach_file_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHigh,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16)),
                            ),
                            builder: (ctx) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    width: 36,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.image_rounded,
                                        color: theme.colorScheme.primary),
                                    title: const Text('Send Image'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _pickAndSendImage();
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.videocam_rounded,
                                        color: theme.colorScheme.primary),
                                    title: const Text('Send Video'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _pickAndSendVideo();
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Text field
                      Expanded(
                        child: Semantics(
                          label: 'Message input field',
                          hint: 'Type a message and press send',
                          child: TextField(
                            controller: _messageController,
                            style: TextStyle(
                              fontSize: 14.5,
                              color: theme.colorScheme.onSurface,
                            ),
                            textInputAction: TextInputAction.send,
                            onTap: () {
                              if (_showEmojiPicker) {
                                setState(() => _showEmojiPicker = false);
                              }
                            },
                            onSubmitted: (val) => _sendMessage(),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(
                                fontSize: 14.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10.0,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  Icons.send_rounded,
                                  color: sendButtonColor,
                                  size: 19,
                                ),
                                onPressed: _sendMessage,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Emoji picker panel ──────────────────────────────────────
              if (_showEmojiPicker)
                SizedBox(
                  height: 280,
                  child: EmojiPicker(
                    onEmojiSelected: _onEmojiSelected,
                    config: Config(
                      emojiViewConfig: EmojiViewConfig(
                        backgroundColor: theme.colorScheme.surfaceContainerLow,
                        columns: 8,
                        emojiSizeMax: 28,
                      ),
                      categoryViewConfig: CategoryViewConfig(
                        backgroundColor: theme.colorScheme.surfaceContainerLow,
                        iconColor: theme.colorScheme.onSurfaceVariant,
                        iconColorSelected: theme.colorScheme.primary,
                        indicatorColor: theme.colorScheme.primary,
                      ),
                      bottomActionBarConfig: const BottomActionBarConfig(
                        enabled: false,
                      ),
                    ),
                  ),
                ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IncomingCastBanner extends StatelessWidget {
  final String hostName;
  final VoidCallback onJoin;

  const _IncomingCastBanner({required this.hostName, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.cast_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$hostName is casting their screen',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
          ),
          TextButton(
            onPressed: onJoin,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Watch', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
