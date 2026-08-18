import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/feature_flags.dart';
import '../generated/app_localizations.dart';
import '../main.dart';
import '../models/types.dart';
import '../theme/app_theme.dart';
import '../utils/fold_layout.dart';
import '../services/auth_service.dart';
import '../services/server_status_service.dart';
import '../services/notification_service.dart';
import '../widgets/active_view_scope.dart';
import '../widgets/drawer_panel.dart';
import '../widgets/profile_panel.dart';
import '../widgets/skeleton_box.dart';
import '../platform_init_stub.dart'
    if (dart.library.io) '../platform_init_io.dart' as platform_init;
import 'real_time_view.dart';
import 'daily_settlement_view.dart';
import 'monthly_view.dart';
import 'marker_view.dart';
import 'ranking_view.dart';

List<(ViewType, String, IconData)> navItems(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    (ViewType.realTime, l10n.navGenInfo, Icons.show_chart),
    (ViewType.daily, l10n.navWeekly, Icons.calendar_today),
    (ViewType.monthly, l10n.navMonthly, Icons.bar_chart),
    (ViewType.marker, l10n.navMarker, Icons.description),
    (ViewType.ranking, l10n.navPerform, Icons.emoji_events),
  ];
}

class LayoutScreen extends StatefulWidget {
  const LayoutScreen({super.key, this.onLogout});

  final VoidCallback? onLogout;

  @override
  State<LayoutScreen> createState() => _LayoutScreenState();
}

/// Order of views in bottom nav and PageView (portrait).
const _viewOrder = [
  ViewType.realTime,
  ViewType.daily,
  ViewType.monthly,
  ViewType.marker,
  ViewType.ranking
];

class _LayoutScreenState extends State<LayoutScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  ViewType _activeView = ViewType.realTime;

  /// When null = no transition. When set, we're animating from _previousView to _activeView.
  ViewType? _previousView;
  late final AnimationController _contentTransitionController;
  late final AnimationController _toastSlideController;
  late final PageController _pageController;
  late Widget _cachedContent;
  Widget? _outgoingContent;
  bool _notificationOpen = false;
  bool _languageOpen = false;
  bool _profileOpen = false;
  bool _showNotificationToast = false;
  bool _isServerOnline = true;
  StreamSubscription<bool>? _serverStatusSub;
  List<NotificationItem> _notifications = [];
  int _notificationTotal = 0;
  bool _notificationsLoading = false;
  bool _notificationsLoadingMore = false;
  static const int _notificationPageSize = 20;
  AuthUser? _currentUser;
  Timer? _notificationPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cachedContent = _buildView(_activeView);
    AuthService.instance.getStoredUser().then((user) {
      if (mounted) setState(() => _currentUser = user);
    });
    _isServerOnline = ServerStatusService.instance.isOnline;
    ServerStatusService.instance.start();
    _serverStatusSub =
        ServerStatusService.instance.isOnlineStream.listen((online) {
      if (mounted) setState(() => _isServerOnline = online);
    });
    if (kNotificationsEnabled) {
      NotificationService.onNotificationsChanged = () {
        if (mounted) _loadNotifications();
      };
      // Load notifications on start so red dot shows for unread without opening panel first
      _loadNotifications();
      // Poll every 2s on other tabs. On Real Time tab, notifications are synced with ongoing games via RealTimeView.onPollTick (same 3s).
      _notificationPollTimer =
          Timer.periodic(const Duration(seconds: 2), (_) async {
        if (!mounted || _activeView == ViewType.realTime) return;
        final enabled = await AuthService.instance.getNotificationsEnabled();
        if (mounted && enabled) _loadNotifications(silent: true);
      });
    }
    _pageController = PageController(initialPage: 0);
    _contentTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _contentTransitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _previousView = null;
            _outgoingContent = null;
          });
        });
      }
    });
    _toastSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _toastSlideController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() => _showNotificationToast = false);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kNotificationsEnabled) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      platform_init.scheduleOneOffNotificationCheck();
    } else if (state == AppLifecycleState.resumed && mounted) {
      AuthService.instance.getNotificationsEnabled().then((enabled) {
        if (mounted && enabled) _loadNotifications();
      });
    }
  }

  @override
  void dispose() {
    _notificationPollTimer?.cancel();
    _toastSlideController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.onNotificationsChanged = null;
    _serverStatusSub?.cancel();
    ServerStatusService.instance.stop();
    _pageController.dispose();
    _contentTransitionController.dispose();
    super.dispose();
  }

  int _indexOfView(ViewType v) {
    final i = _viewOrder.indexOf(v);
    return i >= 0 ? i : 0;
  }

  Future<void> _loadNotifications(
      {bool silent = false,
      bool acceptEmpty = false,
      bool append = false}) async {
    if (!mounted) return;
    final previousIds = Set<int>.from(_notifications.map((n) => n.id));
    final offset = append ? _notifications.length : 0;
    if (append) {
      setState(() => _notificationsLoadingMore = true);
    } else if (!silent) {
      setState(() => _notificationsLoading = true);
    }
    final result = await NotificationService.instance
        .fetchNotifications(limit: _notificationPageSize, offset: offset);
    if (!mounted) return;
    final list = result.list;
    final total = result.total;
    final nextList = append ? [..._notifications, ...list] : list;
    if (!acceptEmpty && !append && list.isEmpty && _notifications.isNotEmpty) {
      setState(() {
        _notificationsLoading = false;
        _notificationsLoadingMore = false;
      });
      return;
    }
    final hasNew = nextList.any((n) => !previousIds.contains(n.id));
    final hasNewUnread =
        hasNew && nextList.any((n) => !previousIds.contains(n.id) && !n.isRead);
    setState(() {
      _notifications = nextList;
      _notificationTotal = total;
      _notificationsLoading = false;
      _notificationsLoadingMore = false;
    });
    if (!append) {
      final notificationsEnabled =
          await AuthService.instance.getNotificationsEnabled();
      final shouldShowToast = mounted && hasNewUnread && notificationsEnabled;
      if (shouldShowToast) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _showNotificationToast = true);
          _toastSlideController.forward();
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) _toastSlideController.reverse();
          });
        });
      }
    }
  }

  Future<void> _markAllNotificationsAsRead() async {
    final ok = await NotificationService.instance.markAllAsRead();
    if (!mounted) return;
    if (ok) await _loadNotifications();
  }

  Future<void> _hideNotification(int id) async {
    final ok = await NotificationService.instance.hideNotification(id);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _notifications = _notifications.where((n) => n.id != id).toList();
        _notificationTotal = (_notificationTotal - 1).clamp(0, 0x7fffffff);
      });
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_notificationsLoadingMore ||
        _notifications.length >= _notificationTotal) return;
    await _loadNotifications(silent: true, append: true);
  }

  Widget _buildNotificationToast(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final isPortrait = size.width < 1024;
    final bottomInset = isPortrait ? 24.0 + 80.0 : 24.0;
    return Positioned(
      right: 0,
      bottom: bottomInset,
      child: Align(
        alignment: Alignment.centerRight,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
              parent: _toastSlideController, curve: Curves.easeOutCubic)),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 320,
              margin: const EdgeInsets.only(right: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: surfaceDarkMid,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(-2, 0)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.newActivityCheckNotifications,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _notificationOpen = true);
                    },
                    child: Text(l10n.viewNotifications,
                        style: TextStyle(
                            color: primaryIndigo, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _clearAllNotifications() async {
    final ok = await NotificationService.instance.clearAll();
    if (!mounted) return;
    if (ok) await _loadNotifications(acceptEmpty: true);
  }

  Future<void> _markNotificationAsRead(NotificationItem n) async {
    if (n.isRead) return;
    final ok = await NotificationService.instance.markAsRead(n.id);
    if (!mounted) return;
    if (ok) {
      setState(() {
        final i = _notifications.indexWhere((x) => x.id == n.id);
        if (i >= 0) _notifications[i] = n.copyWith(isRead: true);
      });
    }
  }

  void _setActiveView(ViewType view, {bool animatePage = false}) {
    if (view == _activeView) return;
    final oldView = _activeView;
    setState(() {
      _previousView = oldView;
      _outgoingContent = _cachedContent;
      _activeView = view;
      _cachedContent = _buildView(view);
    });
    if (animatePage && _pageController.hasClients) {
      final index = _indexOfView(view);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _contentTransitionController.forward(from: 0);
    }
  }

  Widget _buildView(ViewType view) {
    switch (view) {
      case ViewType.realTime:
        return RealTimeView(onPollTick: () => _loadNotifications(silent: true));
      case ViewType.daily:
        return const DailySettlementView();
      case ViewType.monthly:
        return const MonthlyView();
      case ViewType.marker:
        return const MarkerView();
      case ViewType.ranking:
        return const RankingView();
    }
  }

  Widget _buildPortraitPageView(BuildContext context) {
    // Sync page to _activeView when e.g. rotating from landscape
    if (_pageController.hasClients) {
      final currentPage = (_pageController.page ?? 0).round();
      final wantPage = _indexOfView(_activeView);
      if (currentPage != wantPage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(_indexOfView(_activeView));
          }
        });
      }
    }
    return PageView(
      controller: _pageController,
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      onPageChanged: (index) {
        if (index >= 0 && index < _viewOrder.length) {
          setState(() => _activeView = _viewOrder[index]);
        }
      },
      children: _viewOrder.map((v) => _buildPortraitPage(context, v)).toList(),
    );
  }

  /// One page in the portrait PageView carousel.
  Widget _buildPortraitPage(BuildContext context, ViewType view) {
    final padding = EdgeInsets.all(FoldLayout.pagePadding(context));
    const maxWidth = BoxConstraints(maxWidth: 1280);
    final content = ActiveViewScope(
      activeView: view,
      child: _buildView(view),
    );
    if (view == ViewType.ranking ||
        view == ViewType.marker ||
        view == ViewType.realTime ||
        view == ViewType.daily ||
        view == ViewType.monthly) {
      return Padding(
        padding: padding,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: maxWidth,
            child: SizedBox(width: double.infinity, height: double.infinity, child: content),
          ),
        ),
      );
    }
    final wrapped = Center(
      child: ConstrainedBox(
        constraints: maxWidth,
        child: content,
      ),
    );
    return SingleChildScrollView(
      padding: padding,
      child: wrapped,
    );
  }

  String _viewLabel(BuildContext context) {
    final item = navItems(context).firstWhere((e) => e.$1 == _activeView);
    return item.$2;
  }

  /// Incoming only: slide in from right. Outgoing hidden (no fade).
  Widget _buildTransitionContent() {
    final inTransition = _previousView != null;

    return AnimatedBuilder(
      animation: _contentTransitionController,
      builder: (context, _) {
        final t = inTransition
            ? Curves.easeOutCubic.transform(_contentTransitionController.value)
            : 1.0;
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            // Outgoing: hidden (no fade/slide effect)
            if (inTransition)
              IgnorePointer(
                child: Opacity(
                  opacity: 0,
                  child: _outgoingContent ?? const SizedBox.shrink(),
                ),
              ),
            // Incoming: slide from right + fade in
            RepaintBoundary(
              child: Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(40 * (1 - t), 0),
                  child: _cachedContent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 1024;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: scaffoldGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Row(
                children: [
                  if (isWide) _buildSidebar(context),
                  Expanded(
                    child: Column(
                      children: [
                        _buildHeader(context, isWide),
                        Expanded(
                          child: !isWide
                              ? _buildPortraitPageView(context)
                              : (_activeView == ViewType.ranking ||
                                      _activeView == ViewType.marker ||
                                      _activeView == ViewType.realTime ||
                                      _activeView == ViewType.daily ||
                                      _activeView == ViewType.monthly)
                                  ? Padding(
                                      padding: EdgeInsets.all(FoldLayout.pagePadding(context)),
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 1280),
                                          child: ActiveViewScope(
                                            activeView: _activeView,
                                            child: _buildTransitionContent(),
                                          ),
                                        ),
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      padding: EdgeInsets.all(FoldLayout.pagePadding(context)),
                                      child: Center(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 1280),
                                          child: ActiveViewScope(
                                            activeView: _activeView,
                                            child: _buildTransitionContent(),
                                          ),
                                        ),
                                      ),
                                    ),
                        ),
                        if (!isWide) SizedBox(height: FoldLayout.isCompact(context) ? 64 : 80),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isWide)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomNav(context),
                ),
              if (_languageOpen)
                Positioned.fill(
                  child: DrawerPanel(
                    title: AppLocalizations.of(context).language,
                    onClose: () => setState(() => _languageOpen = false),
                    child: Builder(
                      builder: (context) {
                        final l10n = AppLocalizations.of(context);
                        final scope = AppLocaleScope.of(context);
                        final current = scope.locale?.languageCode;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _languageOption(
                              context,
                              flag: '🇺🇸',
                              label: l10n.english,
                              isSelected: current == 'en',
                              onTap: () {
                                scope.setLocale(const Locale('en'));
                                setState(() => _languageOpen = false);
                              },
                            ),
                            const SizedBox(height: 12),
                            _languageOption(
                              context,
                              flag: '🇰🇷',
                              label: l10n.korean,
                              isSelected: current == 'ko',
                              onTap: () {
                                scope.setLocale(const Locale('ko'));
                                setState(() => _languageOpen = false);
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              if (_notificationOpen)
                Positioned.fill(
                  child: DrawerPanel(
                    title: AppLocalizations.of(context).notifications,
                    onClose: () => setState(() => _notificationOpen = false),
                    child: ClipRect(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_notificationsLoading)
                            ...List.generate(
                                5,
                                (_) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: _skeletonNotificationCard(),
                                    ))
                          else ...[
                            if (_notifications.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 32),
                                child: Center(
                                  child: Text(
                                    'No notifications',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.grey[500]),
                                  ),
                                ),
                              )
                            else
                              ..._notifications.map((n) => Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Dismissible(
                                      key: ValueKey<int>(n.id),
                                      direction: DismissDirection.endToStart,
                                      onDismissed: (_) =>
                                          _hideNotification(n.id),
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding:
                                            const EdgeInsets.only(right: 20),
                                        decoration: BoxDecoration(
                                          color:
                                              roseAccent.withValues(alpha: 0.3),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border:
                                              Border.all(color: borderColor),
                                        ),
                                        child: const Icon(Icons.delete_outline,
                                            color: Colors.white70, size: 24),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () =>
                                              _markNotificationAsRead(n),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: cardBg,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: borderColor),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        if (!n.isRead)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    right: 8),
                                                            child: Container(
                                                              width: 8,
                                                              height: 8,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color:
                                                                    roseAccent,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                            ),
                                                          ),
                                                        Text(
                                                          n.title,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                _notificationTitleColor(
                                                                    n),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Text(n.time,
                                                        style: TextStyle(
                                                            fontSize: 9,
                                                            color: Colors
                                                                .grey[500])),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                _buildNotificationMessage(
                                                    n.message),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )),
                            if (_notifications.length < _notificationTotal &&
                                _notifications.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Center(
                                  child: TextButton(
                                    onPressed: _notificationsLoadingMore
                                        ? null
                                        : _loadMoreNotifications,
                                    child: _notificationsLoadingMore
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: primaryIndigo))
                                        : Text(
                                            AppLocalizations.of(context)
                                                .loadMore,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: primaryIndigo)),
                                  ),
                                ),
                              ),
                            if (_notifications.isNotEmpty)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: _markAllNotificationsAsRead,
                                    child: Text(
                                      AppLocalizations.of(context)
                                          .markAllAsRead,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[400]),
                                    ),
                                  ),
                                  Text('·',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                  TextButton(
                                    onPressed: _clearAllNotifications,
                                    child: Text(
                                      AppLocalizations.of(context)
                                          .clearAllNotifications,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500]),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              if (_profileOpen)
                Positioned.fill(
                  child: ProfilePanel(
                    onClose: () => setState(() => _profileOpen = false),
                    onLogout: () => widget.onLogout?.call(),
                    currentUser: _currentUser,
                  ),
                ),
              if (_showNotificationToast) _buildNotificationToast(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _languageOption(BuildContext context,
      {required String flag,
      required String label,
      required bool isSelected,
      required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? primaryIndigo : borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.check,
                  size: 20, color: isSelected ? primaryIndigo : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? primaryIndigo : Colors.white)),
              ),
              const SizedBox(width: 12),
              Text(flag, style: const TextStyle(fontSize: 24, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeletonNotificationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SkeletonBox(width: 120, height: 12, borderRadius: 4),
              const SkeletonBox(width: 48, height: 9, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 8),
          const SkeletonBox(
              height: 11, width: double.infinity, borderRadius: 4),
          const SizedBox(height: 4),
          const SkeletonBox(height: 11, width: 200, borderRadius: 4),
        ],
      ),
    );
  }

  Color _notificationTitleColor(NotificationItem n) {
    final type = n.type;
    switch (type) {
      case 'game_start':
        return emeraldAccent;
      case 'buy_in':
        return amberAccent;
      case 'cash_out':
        return tealAccent;
      case 'game_ended':
        return accentPurple;
      case 'urgent':
        return roseAccent;
      case 'success':
        return emeraldAccent;
      case 'warning':
        return amberAccent;
      default:
        // Fallback by title for old notifications with type 'info'
        final t = n.title.toLowerCase();
        if (t.contains('game started') || t.contains('new game'))
          return emeraldAccent;
        if (t.contains('buy-in added') || t.contains('buy in added'))
          return amberAccent;
        if (t.contains('cash-out added') || t.contains('cash out added'))
          return tealAccent;
        if (t.contains('game ended') || t.contains('has ended'))
          return accentPurple;
        return primaryIndigo;
    }
  }

  static const _winLossPrefix = ' – Win/Loss: ';

  Widget _buildNotificationMessage(String message) {
    final grey = TextStyle(fontSize: 13, color: Colors.grey[300]);
    final idx = message.indexOf(_winLossPrefix);
    if (idx < 0) {
      return Text(message, style: grey);
    }
    final before = message.substring(0, idx);
    final winLossPart = message.substring(idx + _winLossPrefix.length);
    final trimmed = winLossPart.trim();
    final isNegative = trimmed.startsWith('-') ||
        trimmed.contains('−') ||
        trimmed.startsWith('P-') ||
        trimmed.startsWith('₱-');
    final winLossColor = isNegative ? roseAccent : emeraldAccent;
    return RichText(
      text: TextSpan(
        style: grey,
        children: [
          TextSpan(text: before),
          TextSpan(
            text: _winLossPrefix + winLossPart,
            style: TextStyle(
                fontSize: 13, color: winLossColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: appBarBackground.withValues(alpha: 0.95),
        border: Border(
          right: BorderSide(color: borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            offset: const Offset(2, 0),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Image.asset('assets/images/logoOnly.png',
                        width: 58, height: 58, fit: BoxFit.contain),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context).appTitle,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        Text(AppLocalizations.of(context).executive,
                            style: TextStyle(
                                fontSize: 10,
                                color: primaryIndigo,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(AppLocalizations.of(context).mainMenu,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 2)),
                ),
              ),
              const SizedBox(height: 16),
              ...navItems(context).map((e) {
                final isActive = _activeView == e.$1;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _setActiveView(e.$1),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? primaryIndigo.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isActive
                                  ? primaryIndigo.withValues(alpha: 0.2)
                                  : Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            Icon(e.$3,
                                size: 20,
                                color: isActive ? primaryIndigo : Colors.grey),
                            const SizedBox(width: 12),
                            Text(e.$2,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? primaryIndigo
                                        : Colors.grey)),
                            if (isActive) const Spacer(),
                            if (isActive)
                              Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                      color: primaryIndigo,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: primaryIndigo.withValues(
                                                alpha: 0.8),
                                            blurRadius: 8)
                                      ])),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _profileOpen = true),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                          radius: 20,
                          backgroundColor: primaryIndigo.withValues(alpha: 0.3),
                          child: const Icon(Icons.person,
                              color: Colors.white, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                _currentUser?.displayName ??
                                    AppLocalizations.of(context).executiveBoss,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                                _currentUser?.permissions == 1
                                    ? AppLocalizations.of(context).administrator
                                    : (_currentUser?.role ??
                                        AppLocalizations.of(context)
                                            .administrator),
                                style: TextStyle(
                                    fontSize: 10, color: emeraldAccent),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // sample.html .tabs-nav::before — vertical gradient line on right edge
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: 1,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    primaryIndigo.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isWide) {
    final compact = FoldLayout.isCompact(context);
    final iconDensity = compact ? VisualDensity.compact : VisualDensity.standard;
    return Container(
      height: compact ? 56 : 80,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16),
      decoration: BoxDecoration(
        color: appBarBackground.withValues(alpha: 0.3),
      ),
      child: Row(
        children: [
          if (!isWide) ...[
            Image.asset('assets/images/logoOnly.png',
                width: compact ? 32 : 46, height: compact ? 32 : 46, fit: BoxFit.contain),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.of(context).appTitle,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
          if (isWide)
            Text(
              _viewLabel(context),
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5),
            ),
          if (isWide) const Spacer(),
          if (isWide)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isServerOnline ? emeraldAccent : roseAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isServerOnline
                        ? AppLocalizations.of(context).systemStatusLive
                        : AppLocalizations.of(context).systemStatusOffline,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _isServerOnline ? Colors.grey : roseAccent,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          if (!compact) const SizedBox(width: 16),
          IconButton(
            visualDensity: iconDensity,
            tooltip: AppLocalizations.of(context).language,
            onPressed: () => setState(() => _languageOpen = true),
            icon: const Icon(Icons.language, color: Colors.grey, size: 24),
          ),
          if (kNotificationsEnabled)
            IconButton(
              visualDensity: iconDensity,
              onPressed: () {
                setState(() => _notificationOpen = true);
                _loadNotifications();
              },
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_none,
                      color: Colors.grey, size: 24),
                  if (_notifications.any((n) => !n.isRead))
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: roseAccent, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
            ),
          if (!isWide)
            IconButton(
              visualDensity: iconDensity,
              onPressed: () => setState(() => _profileOpen = true),
              icon: CircleAvatar(
                  radius: compact ? 14 : 18,
                  backgroundColor: primaryIndigo,
                  child:
                      const Icon(Icons.person, size: 18, color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final navBg = appBarBackground.withValues(alpha: 0.95);
    return Container(
      decoration: BoxDecoration(
        color: navBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            offset: const Offset(0, -3),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top border: same idea as sidebar right — color in center, fade left/right (transparent → indigo → transparent)
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  borderColor,
                  primaryIndigo.withValues(alpha: 0.5),
                  borderColor,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                vertical: FoldLayout.isCompact(context) ? 6 : 16),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: navItems(context).map((e) {
                  final isActive = _activeView == e.$1;
                  return Expanded(
                    child: InkWell(
                      onTap: () => _setActiveView(e.$1, animatePage: true),
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: isActive
                                ? BoxDecoration(
                                    color: primaryIndigo.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12))
                                : null,
                            child: Icon(e.$3,
                                size: 22,
                                color: isActive ? primaryIndigo : Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              e.$2,
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color:
                                      isActive ? primaryIndigo : Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
