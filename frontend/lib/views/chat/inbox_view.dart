import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/chat_repository.dart';
import '../../core/network/socket_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../auth/login_view.dart';
import '../shared/connection_status_banner.dart';
import '../shared/empty_state_widget.dart';
import '../shared/online_status_indicator.dart';
import 'chat_room_view.dart';

class InboxView extends StatefulWidget {
  const InboxView({super.key});

  @override
  State<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<InboxView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.fetchConversations();
      chatProvider.fetchUsers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final socketService = Provider.of<SocketService>(context, listen: false);

    await chatProvider.clear();
    socketService.disconnect();

    await authProvider.logout();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginView(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
        (route) => false,
      );
    }
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (now.year == dt.year &&
        now.month == dt.month &&
        now.day == dt.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1 ||
        (now.day - dt.day == 1 && now.month == dt.month)) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      final List<String> weekdays = [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ];
      return weekdays[dt.weekday - 1];
    } else {
      return '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}';
    }
  }

  Widget _buildCheckmarks(String status, ThemeData theme) {
    if (status == 'pending') {
      return Icon(
        Icons.schedule_rounded,
        size: 14,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      );
    }

    final bool isRead = status == 'read';
    return Icon(
      isRead ? Icons.done_all_rounded : Icons.done_all_rounded,
      size: 16,
      color: isRead
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final theme = Theme.of(context);
    final user = authProvider.currentUser;

    final filteredConversations = chatProvider.conversations.where((convo) {
      if (_searchQuery.isEmpty) return true;
      final recipient = convo.participants.firstWhere(
        (p) => p.id != user?.id,
        orElse: () => user!,
      );
      final matchName = convo.isGroup
          ? convo.groupName.toLowerCase().contains(_searchQuery)
          : recipient.name.toLowerCase().contains(_searchQuery);
      final matchMessage =
          convo.lastMessage?.content.toLowerCase().contains(_searchQuery) ??
          false;
      return matchName || matchMessage;
    }).toList();

    final filteredUsers = chatProvider.users.where((otherUser) {
      if (_searchQuery.isEmpty) return true;
      return otherUser.name.toLowerCase().contains(_searchQuery) ||
          otherUser.email.toLowerCase().contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundImage:
                  user?.profileImage != null && user!.profileImage.isNotEmpty
                  ? NetworkImage(user.profileImage)
                  : null,
              child: Text(
                user?.name.substring(0, 1).toUpperCase() ?? 'U',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Chat User',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Active session',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.logout_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 22,
            ),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search chats, users...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: theme.colorScheme.primary,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorWeight: 2.5,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 16),
                              SizedBox(width: 8),
                              Text('Chats'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline_rounded, size: 17),
                              SizedBox(width: 8),
                              Text('Users'),
                            ],
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
      ),
      body: Column(
        children: [
          const ConnectionStatusBanner(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    RefreshIndicator(
                      onRefresh: () => chatProvider.fetchConversations(),
                      color: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surface,
                      strokeWidth: 2.5,
                      child: chatProvider.isLoading
                          ? const EmptyStateWidget(
                              variant: EmptyStateVariant.loading,
                            )
                          : filteredConversations.isEmpty
                          ? EmptyStateWidget(
                              variant: _searchQuery.isNotEmpty
                                  ? EmptyStateVariant.noUsersFound
                                  : EmptyStateVariant.noConversations,
                              subtitle: _searchQuery.isNotEmpty
                                  ? 'No conversation matches "$_searchQuery".'
                                  : null,
                              actionLabel: _searchQuery.isEmpty
                                  ? 'Browse People'
                                  : null,
                              onAction: _searchQuery.isEmpty
                                  ? () => _tabController.animateTo(1)
                                  : null,
                            )
                          : ListView.separated(
                              itemCount: filteredConversations.length,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                thickness: 0.5,
                                indent: 76,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                              ),
                              itemBuilder: (context, index) {
                                final convo = filteredConversations[index];
                                final recipient = convo.participants.firstWhere(
                                  (p) => p.id != user?.id,
                                  orElse: () => user!,
                                );

                                final isMe =
                                    convo.lastMessage?.sender.id == user?.id;
                                final bool isUnread =
                                    convo.lastMessage != null &&
                                    !isMe &&
                                    convo.lastMessage!.status != 'read';

                                return TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0.0, end: 1.0),
                                  duration: Duration(
                                    milliseconds: 200 + (index * 40).clamp(0, 200),
                                  ),
                                  curve: Curves.easeOut,
                                  builder: (context, value, child) {
                                    return Transform.translate(
                                      offset: Offset(0, 16.0 * (1.0 - value)),
                                      child: Opacity(opacity: value, child: child),
                                    );
                                  },
                                  child: Semantics(
                                    label: 'Chat with ${convo.isGroup ? convo.groupName : recipient.name}. ${isUnread ? 'Unread messages.' : ''} Last message: ${convo.lastMessage?.content ?? "None"}',
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      leading: Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: theme.colorScheme.primaryContainer
                                                      .withValues(alpha: 0.3),
                                            foregroundImage:
                                                recipient.profileImage.isNotEmpty
                                                ? NetworkImage(recipient.profileImage)
                                                : null,
                                            child: Text(
                                              recipient.name
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          if (recipient.isOnline)
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: OnlineStatusIndicator(
                                                isOnline: true,
                                                size: 13,
                                                borderColor: theme.colorScheme.surface,
                                              ),
                                            ),
                                        ],
                                      ),
                                      title: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              convo.isGroup
                                                  ? convo.groupName
                                                  : recipient.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: isUnread
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                                fontSize: 15,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            convo.lastMessage != null
                                                ? _formatDateTime(
                                                    convo.lastMessage!.createdAt,
                                                  )
                                                : '',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: isUnread
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isUnread
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Row(
                                          children: [
                                            if (isMe &&
                                                convo.lastMessage != null) ...[
                                              _buildCheckmarks(
                                                convo.lastMessage!.status,
                                                theme,
                                              ),
                                              const SizedBox(width: 5),
                                            ],
                                            Expanded(
                                              child: Text(
                                                convo.lastMessage != null
                                                    ? (isMe
                                                          ? 'You: ${convo.lastMessage!.content}'
                                                          : convo
                                                                .lastMessage!
                                                                .content)
                                                    : 'No messages yet',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isUnread
                                                      ? theme.colorScheme.onSurface
                                                      : theme.colorScheme.onSurfaceVariant,
                                                  fontWeight: isUnread
                                                      ? FontWeight.w500
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                            if (isUnread) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.primary,
                                                  borderRadius: BorderRadius.circular(
                                                    10,
                                                  ),
                                                ),
                                                child: const Text(
                                                  '1',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      onTap: () {
                                        chatProvider.selectConversation(convo.id);
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ChatRoomView(
                                              conversationTitle: convo.isGroup
                                                  ? convo.groupName
                                                  : recipient.name,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    RefreshIndicator(
                      onRefresh: () => chatProvider.fetchUsers(),
                      color: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surface,
                      strokeWidth: 2.5,
                      child: chatProvider.isLoading
                          ? const EmptyStateWidget(
                              variant: EmptyStateVariant.loading,
                            )
                          : filteredUsers.isEmpty
                          ? EmptyStateWidget(
                              variant: EmptyStateVariant.noUsersFound,
                              subtitle: _searchQuery.isNotEmpty
                                  ? 'No users match "$_searchQuery". Try a different name.'
                                  : 'No other users found on this server.',
                            )
                          : ListView.separated(
                              itemCount: filteredUsers.length,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                thickness: 0.5,
                                indent: 76,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                              ),
                              itemBuilder: (context, index) {
                                final otherUser = filteredUsers[index];

                                return TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0.0, end: 1.0),
                                  duration: Duration(
                                    milliseconds: 200 + (index * 40).clamp(0, 200),
                                  ),
                                  curve: Curves.easeOut,
                                  builder: (context, value, child) {
                                    return Transform.translate(
                                      offset: Offset(0, 16.0 * (1.0 - value)),
                                      child: Opacity(opacity: value, child: child),
                                    );
                                  },
                                  child: Semantics(
                                    label: 'Start chat with user ${otherUser.name}. ${otherUser.isOnline ? "Online" : "Offline"}.',
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      leading: Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: theme.colorScheme.secondaryContainer
                                                      .withValues(alpha: 0.3),
                                            foregroundImage:
                                                otherUser.profileImage.isNotEmpty
                                                ? NetworkImage(otherUser.profileImage)
                                                : null,
                                            child: Text(
                                              otherUser.name
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: theme.colorScheme.secondary,
                                              ),
                                            ),
                                          ),
                                          if (otherUser.isOnline)
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: OnlineStatusIndicator(
                                                isOnline: true,
                                                size: 13,
                                                borderColor: theme.colorScheme.surface,
                                              ),
                                            ),
                                        ],
                                      ),
                                      title: Text(
                                        otherUser.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          otherUser.email,
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                      trailing: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      onTap: () async {
                                        final chatRepo = Provider.of<ChatRepository>(
                                          context,
                                          listen: false,
                                        );

                                        try {
                                          final conversation = await chatRepo
                                              .createOrGetConversation(
                                                participantId: otherUser.id,
                                              );

                                          chatProvider.selectConversation(
                                            conversation.id,
                                          );

                                          if (context.mounted) {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => ChatRoomView(
                                                  conversationTitle: otherUser.name,
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to start conversation: $e',
                                                ),
                                                backgroundColor:
                                                    theme.colorScheme.error,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
