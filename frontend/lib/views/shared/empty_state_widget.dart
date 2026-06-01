import 'package:flutter/material.dart';

enum EmptyStateVariant {
  noConversations,
  noUsersFound,
  noInternet,
  loading,
  serverUnavailable,
}

class EmptyStateWidget extends StatefulWidget {
  final EmptyStateVariant variant;

  final String? actionLabel;
  final VoidCallback? onAction;

  final String? subtitle;

  const EmptyStateWidget({
    super.key,
    required this.variant,
    this.actionLabel,
    this.onAction,
    this.subtitle,
  });

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _slideAnim;
  late final Animation<double> _iconBounceAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _slideAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
    );
    _iconBounceAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _EmptyStateConfig _resolveConfig(ThemeData theme, bool isDark) {
    final cs = theme.colorScheme;
    switch (widget.variant) {
      case EmptyStateVariant.noConversations:
        return _EmptyStateConfig(
          icon: Icons.chat_bubble_outline_rounded,
          iconColor: cs.primary,
          iconBgColor: cs.primaryContainer,
          title: 'No Conversations Yet',
          subtitle:
              widget.subtitle ??
              'Start chatting by tapping a user\nfrom the People tab.',
          actionLabel: widget.actionLabel ?? 'Browse People',
          accentColor: cs.primary,
        );
      case EmptyStateVariant.noUsersFound:
        return _EmptyStateConfig(
          icon: Icons.person_search_rounded,
          iconColor: cs.secondary,
          iconBgColor: cs.secondaryContainer,
          title: 'No Users Found',
          subtitle:
              widget.subtitle ??
              'Try a different search term\nor clear the search bar.',
          accentColor: cs.secondary,
        );
      case EmptyStateVariant.noInternet:
        return _EmptyStateConfig(
          icon: Icons.wifi_off_rounded,
          iconColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
          iconBgColor: isDark
              ? const Color(0xFF422006)
              : const Color(0xFFFEF3C7),
          title: 'No Internet Connection',
          subtitle:
              widget.subtitle ??
              'Please check your network\nsettings and try again.',
          actionLabel: widget.actionLabel ?? 'Retry',
          accentColor: isDark
              ? const Color(0xFFFBBF24)
              : const Color(0xFFD97706),
        );
      case EmptyStateVariant.loading:
        return _EmptyStateConfig(
          icon: Icons.hourglass_top_rounded,
          iconColor: cs.primary,
          iconBgColor: cs.primaryContainer,
          title: 'Loading…',
          subtitle:
              widget.subtitle ?? 'Fetching your conversations.\nJust a moment.',
          accentColor: cs.primary,
          isLoading: true,
        );
      case EmptyStateVariant.serverUnavailable:
        return _EmptyStateConfig(
          icon: Icons.cloud_off_rounded,
          iconColor: isDark ? const Color(0xFFFC8181) : const Color(0xFFDC2626),
          iconBgColor: isDark
              ? const Color(0xFF450A0A)
              : const Color(0xFFFEE2E2),
          title: 'Server Unavailable',
          subtitle:
              widget.subtitle ??
              'Our servers are temporarily\ndown. Please try again later.',
          actionLabel: widget.actionLabel ?? 'Try Again',
          accentColor: isDark
              ? const Color(0xFFFC8181)
              : const Color(0xFFDC2626),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final config = _resolveConfig(theme, isDark);

    return Center(
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _iconBounceAnim,
                builder: (_, child) =>
                    Transform.scale(scale: _iconBounceAnim.value, child: child),
                child: _IconBadge(
                  icon: config.icon,
                  iconColor: config.iconColor,
                  bgColor: config.iconBgColor,
                  isLoading: config.isLoading,
                ),
              ),

              const SizedBox(height: 28),

              AnimatedBuilder(
                animation: _slideAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, 20 * (1 - _slideAnim.value)),
                  child: child,
                ),
                child: Text(
                  config.title,
                  textAlign: TextAlign.center,
                  semanticsLabel: config.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              AnimatedBuilder(
                animation: _slideAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, 20 * (1 - _slideAnim.value)),
                  child: child,
                ),
                child: Text(
                  config.subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white54 : Colors.black45,
                    height: 1.55,
                  ),
                ),
              ),

              if (config.actionLabel != null && widget.onAction != null) ...[
                const SizedBox(height: 28),
                AnimatedBuilder(
                  animation: _fadeAnim,
                  builder: (_, child) =>
                      Opacity(opacity: _fadeAnim.value, child: child),
                  child: FilledButton.tonal(
                    onPressed: widget.onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: config.accentColor.withValues(
                        alpha: 0.12,
                      ),
                      foregroundColor: config.accentColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      elevation: 0,
                    ),
                    child: Text(config.actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStateConfig {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final Color accentColor;
  final bool isLoading;

  const _EmptyStateConfig({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    required this.accentColor,
    this.isLoading = false,
  });
}

class _IconBadge extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final bool isLoading;

  const _IconBadge({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.isLoading = false,
  });

  @override
  State<_IconBadge> createState() => _IconBadgeState();
}

class _IconBadgeState extends State<_IconBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, child) {
        final scale = widget.isLoading
            ? 1.0
            : (0.97 + 0.03 * _pulseController.value);
        return Transform.scale(scale: scale, child: child);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.bgColor.withValues(alpha: 0.4),
            ),
          ),

          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.bgColor,
            ),
            child: widget.isLoading
                ? Padding(
                    padding: const EdgeInsets.all(22),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: widget.iconColor,
                    ),
                  )
                : Icon(widget.icon, size: 36, color: widget.iconColor),
          ),
        ],
      ),
    );
  }
}
