import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isConsecutive;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isConsecutive = false,
    this.onReply,
    this.onDelete,
  });

  Widget _buildStatusIndicator(String status, ThemeData theme) {
    if (status == 'pending') {
      return Icon(
        Icons.access_time_rounded,
        size: 11,
        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
      );
    }

    final bool isRead = status == 'read';
    return Icon(
      Icons.done_all_rounded,
      size: 14,
      color: isRead
          ? theme.colorScheme.primary
          : (isMe
                ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
    );
  }

  Widget _buildMediaContent(BuildContext context, ThemeData theme, Color textColor) {
    if (message.messageType == 'image' && message.fileUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: message.fileUrl,
          width: 220,
          fit: BoxFit.cover,
          placeholder: (ctx, url) => Container(
            width: 220,
            height: 160,
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (ctx, url, err) => Container(
            width: 220,
            height: 80,
            color: theme.colorScheme.errorContainer,
            child: Icon(Icons.broken_image_rounded,
                color: theme.colorScheme.onErrorContainer),
          ),
        ),
      );
    }

    if (message.messageType == 'video' && message.fileUrl.isNotEmpty) {
      return GestureDetector(
        onTap: () {
          // Video messages open the WatchTogetherScreen
          // Navigation is handled by the parent via the message's fileUrl
        },
        child: Container(
          width: 220,
          height: 130,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const Icon(Icons.play_circle_filled_rounded,
                  size: 52, color: Colors.white),
              Positioned(
                bottom: 8,
                left: 10,
                child: Text(
                  'Video',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default: text
    return const SizedBox.shrink();
  }

  void _showActionSheet(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
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
              ListTile(
                leading: Icon(
                  Icons.reply_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  'Reply',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (onReply != null) onReply!();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.copy_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  'Copy Text',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied to clipboard'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              if (isMe && onDelete != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete Message',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onDelete!();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    bool hasQuote = false;
    String? quoteSender;
    String? quoteText;
    String displayContent = message.content;

    if (message.content.startsWith('"> ["') ||
        message.content.startsWith('> [')) {
      final startIndex = message.content.indexOf('[');
      final endIndex = message.content.indexOf(']');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        quoteSender = message.content.substring(startIndex + 1, endIndex);
        final bodyIndex = message.content.indexOf('\n\n', endIndex);
        if (bodyIndex != -1) {
          quoteText = message.content.substring(endIndex + 1, bodyIndex).trim();
          displayContent = message.content.substring(bodyIndex + 2);
          hasQuote = true;
        }
      }
    }

    final Color bubbleColor = isMe
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;

    final Color textColor = isMe
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    final Color quoteBorderColor = theme.colorScheme.primary;

    final Color senderNameColor = isMe
        ? theme.colorScheme.primary
        : theme.colorScheme.primary;

    final Color quoteTextColor = isMe
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    final Color timeColor = isMe
        ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
        : theme.colorScheme.onSurfaceVariant;

    final BorderRadius bubbleRadius = isConsecutive
        ? BorderRadius.circular(20)
        : BorderRadius.only(
            topLeft: Radius.circular(isMe ? 12 : 20),
            topRight: Radius.circular(isMe ? 20 : 12),
            bottomLeft: const Radius.circular(20),
            bottomRight: const Radius.circular(20),
          );

    final timeString =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutQuad,
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue,
          child: Transform.scale(
            scale: 0.95 + (0.05 * animValue),
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: child,
          ),
        );
      },
      child: RepaintBoundary(
        child: Semantics(
          label: '${isMe ? "You" : message.sender.name}: $displayContent',
          child: GestureDetector(
            onDoubleTap: onReply,
            onLongPress: () => _showActionSheet(context),
            child: Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: EdgeInsets.only(
                  top: isConsecutive ? 2.0 : 6.0,
                  bottom: 2.0,
                  left: isMe ? 50.0 : 12.0,
                  right: isMe ? 12.0 : 50.0,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: bubbleRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.25 : 0.05,
                      ),
                      blurRadius: 2.0,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isMe && !isConsecutive) ...[
                          Text(
                            message.sender.name,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: senderNameColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],

                        if (hasQuote &&
                            quoteSender != null &&
                            quoteText != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: isMe ? 0.08 : 0.04,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  Container(
                                    width: 4.5,
                                    decoration: BoxDecoration(
                                      color: quoteBorderColor,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(6),
                                        bottomLeft: Radius.circular(6),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            quoteSender,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: quoteBorderColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            quoteText,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: quoteTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        if (message.messageType == 'image' ||
                            message.messageType == 'video')
                          _buildMediaContent(context, theme, textColor)
                        else
                          Text(
                            displayContent,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14.5,
                              height: 1.35,
                            ),
                          ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 24),
                            Text(
                              timeString,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: timeColor,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              _buildStatusIndicator(message.status, theme),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
