import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../generated/app_localizations.dart';
import '../models/types.dart';
import '../services/ranking_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skeleton_box.dart';

final _fmt = NumberFormat.compact(locale: 'en_PH');

/// Sort ranking by this metric; rank order changes per filter.
enum RankSort { rolling, winLoss, commission }

class RankingView extends StatefulWidget {
  const RankingView({super.key});

  @override
  State<RankingView> createState() => _RankingViewState();
}

class _RankingViewState extends State<RankingView> {
  final RankingService _service = RankingService.instance;
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 20;
  static const int _maxFetchForSort = 500;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<RankingItem> _ranking = [];
  int _total = 0;
  RankSort _sortBy = RankSort.rolling;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_sortBy != RankSort.rolling) return;
    if (_loadingMore || _ranking.isEmpty || _ranking.length >= _total) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) _loadMore();
  }

  /// True if WinLoss=0, Rolling=0, Commission=0 — such entries go to the bottom.
  static bool _isAllZeros(RankingItem item) {
    final net = item.winnings - item.losses;
    return net == 0 && item.rolling == 0 && item.commission == 0;
  }

  /// Puts all-zero entries at the end, keeps relative order otherwise.
  static List<RankingItem> _zerosToBottom(List<RankingItem> list) {
    final nonZero = list.where((e) => !_isAllZeros(e)).toList();
    final zeros = list.where(_isAllZeros).toList();
    return [...nonZero, ...zeros];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _ranking = [];
      _total = 0;
    });
    try {
      if (_sortBy == RankSort.rolling) {
        final result = await _service.fetch(limit: _pageSize, offset: 0);
        if (!mounted) return;
        setState(() {
          _ranking = _zerosToBottom(result.list);
          _total = result.total;
          _loading = false;
        });
      } else {
        final result = await _service.fetch(limit: _maxFetchForSort, offset: 0);
        if (!mounted) return;
        final list = result.list;
        final sorted = List<RankingItem>.from(list);
        if (_sortBy == RankSort.winLoss) {
          sorted.sort((a, b) {
            final netA = a.winnings - a.losses;
            final netB = b.winnings - b.losses;
            return netB.compareTo(netA);
          });
        } else {
          sorted.sort((a, b) => b.commission.compareTo(a.commission));
        }
        setState(() {
          _ranking = _zerosToBottom(sorted);
          _total = sorted.length;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load ranking';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_sortBy != RankSort.rolling || _loadingMore || _ranking.length >= _total) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _service.fetch(limit: _pageSize, offset: _ranking.length);
      if (!mounted) return;
      setState(() {
        _ranking = _zerosToBottom([..._ranking, ...result.list]);
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (MediaQuery.sizeOf(context).height - 200).clamp(400.0, 1200.0);
        return _buildContent(context, maxHeight);
      },
    );
  }

  Widget _buildContent(BuildContext context, double maxHeight) {
    final l10n = AppLocalizations.of(context);
    if (_loading && _ranking.isEmpty) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: _buildSkeletonContent(context),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: TextStyle(color: Colors.grey[400])),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(backgroundColor: primaryIndigo),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_ranking.isEmpty) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeaderWithFilters(context, l10n),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('No ranking data', style: TextStyle(fontSize: 15, color: Colors.grey[500])),
              ),
            ),
          ],
        ),
      );
    }
    final hasMore = _sortBy == RankSort.rolling && _ranking.length < _total;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderWithFilters(context, l10n),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _ranking.length + (hasMore ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= _ranking.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: primaryIndigo),
                      ),
                    ),
                  );
                }
                return _buildRankCard(context, l10n, _ranking[i], displayRank: i + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderWithFilters(BuildContext context, AppLocalizations l10n) {
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 500;
    final titleStyle = TextStyle(
      fontSize: isNarrow ? 16 : 20,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      letterSpacing: -0.5,
      fontStyle: FontStyle.italic,
    );
    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isNarrow ? 8 : 12),
                decoration: BoxDecoration(
                  color: amberAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: amberAccent.withValues(alpha: 0.2), blurRadius: 12)],
                ),
                child: Icon(Icons.emoji_events, color: amberAccent, size: isNarrow ? 24 : 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.guestAgentRanking,
                  style: titleStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFilterSegments(l10n, compact: true),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: amberAccent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: amberAccent.withValues(alpha: 0.2), blurRadius: 12)],
          ),
          child: Icon(Icons.emoji_events, color: amberAccent, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            l10n.guestAgentRanking,
            style: titleStyle,
          ),
        ),
        _buildFilterSegments(l10n, compact: false),
      ],
    );
  }

  Widget _buildFilterSegments(AppLocalizations l10n, {bool compact = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(compact ? 10 : 14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (compact) ...[
            Expanded(child: _filterSegment(l10n.rollingVolume, RankSort.rolling, isFirst: true, compact: true)),
            Expanded(child: _filterSegment(l10n.winLoss, RankSort.winLoss, isFirst: false, compact: true)),
            Expanded(child: _filterSegment(l10n.commission, RankSort.commission, isFirst: false, isLast: true, compact: true)),
          ] else ...[
            _filterSegment(l10n.rollingVolume, RankSort.rolling, isFirst: true, compact: false),
            _filterSegment(l10n.winLoss, RankSort.winLoss, isFirst: false, compact: false),
            _filterSegment(l10n.commission, RankSort.commission, isFirst: false, isLast: true, compact: false),
          ],
        ],
      ),
    );
  }

  Widget _filterSegment(String label, RankSort value, {required bool isFirst, bool isLast = false, bool compact = false}) {
    final selected = _sortBy == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_sortBy != value) {
            setState(() => _sortBy = value);
            _load();
          }
        },
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(isFirst ? (compact ? 10 : 12) : 4),
          right: Radius.circular(isLast ? (compact ? 10 : 12) : 4),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 18, vertical: compact ? 8 : 12),
          decoration: BoxDecoration(
            color: selected ? primaryIndigo.withValues(alpha: 0.35) : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(isFirst ? (compact ? 10 : 12) : 4),
              right: Radius.circular(isLast ? (compact ? 10 : 12) : 4),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primaryIndigo.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 0),
                    ),
                  ]
                : null,
          ),
          child: compact
              ? Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : Colors.white.withValues(alpha: 0.85),
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildRankCard(BuildContext context, AppLocalizations l10n, RankingItem item, {required int displayRank}) {
    final nameMatch = RegExp(r'^(.+?)\s*\(([^)]+)\)\s*$').firstMatch(item.name);
    final displayName = nameMatch != null ? nameMatch.group(1)!.trim() : item.name;
    final codeSubtitle = nameMatch?.group(2)!.trim();
    final net = item.winnings - item.losses;
    final isZero = net == 0;
    final isNegative = net < 0;
    final winLossText = isZero ? '0' : (isNegative ? '-₱${_fmt.format(net.abs())}' : '₱${_fmt.format(net)}');
    final winLossColor = isZero ? Colors.white : (isNegative ? roseAccent : emeraldAccent);
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: isMobile ? _buildMobileRankCard(
          item: item,
          displayRank: displayRank,
          displayName: displayName,
          codeSubtitle: codeSubtitle,
          winLossText: winLossText,
          winLossColor: winLossColor,
          l10n: l10n,
        ) : _buildDesktopRankCard(
          item: item,
          displayRank: displayRank,
          displayName: displayName,
          codeSubtitle: codeSubtitle,
          winLossText: winLossText,
          winLossColor: winLossColor,
          l10n: l10n,
        ),
      ),
    );
  }

  Widget _buildMobileRankCard({
    required RankingItem item,
    required int displayRank,
    required String displayName,
    required String? codeSubtitle,
    required String winLossText,
    required Color winLossColor,
    required AppLocalizations l10n,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVerySmall = constraints.maxWidth < 350;
        final iconSize = isVerySmall ? 40.0 : 48.0;
        final nameSize = isVerySmall ? 14.0 : 16.0;
        final codeSize = isVerySmall ? 10.0 : 11.0;
        final labelSize = isVerySmall ? 8.0 : 9.0;
        final valueSize = isVerySmall ? 12.0 : 14.0;
        final spacing = isVerySmall ? 8.0 : 12.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (displayRank == 1) Icon(Icons.emoji_events, size: iconSize - 12, color: amberAccent),
                      if (displayRank == 2) Icon(Icons.emoji_events, size: iconSize - 12, color: Colors.grey[400]),
                      if (displayRank == 3) Icon(Icons.emoji_events, size: iconSize - 12, color: Colors.amber[800]),
                      if (displayRank > 3) Icon(Icons.military_tech, size: iconSize - 12, color: primaryIndigo.withValues(alpha: 0.5)),
                      Positioned(
                        bottom: 2,
                        child: Text(
                          '$displayRank',
                          style: TextStyle(
                            fontSize: isVerySmall ? 10 : 12,
                            fontWeight: FontWeight.bold,
                            color: displayRank <= 3 ? Colors.black87 : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontSize: nameSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (codeSubtitle != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isVerySmall ? 8 : 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryIndigo.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: primaryIndigo.withValues(alpha: 0.35), blurRadius: 10),
                      ],
                    ),
                    child: Text(
                      codeSubtitle,
                      style: TextStyle(
                        fontSize: codeSize,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.winLoss.toUpperCase(),
                          style: TextStyle(
                            fontSize: labelSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.4),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          winLossText,
                          style: TextStyle(
                            fontSize: valueSize,
                            fontWeight: FontWeight.bold,
                            color: winLossColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isVerySmall ? 16 : 24),
                // Rolling Volume
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.rollingVolume.toUpperCase(),
                          style: TextStyle(
                            fontSize: labelSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.4),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '₱${_fmt.format(item.rolling)}',
                          style: TextStyle(
                            fontSize: valueSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: spacing),
                // Commission (same style as Rolling / WinLoss)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.commission.toUpperCase(),
                          style: TextStyle(
                            fontSize: labelSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.4),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '₱${_fmt.format(item.commission)}',
                          style: TextStyle(
                            fontSize: valueSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopRankCard({
    required RankingItem item,
    required int displayRank,
    required String displayName,
    required String? codeSubtitle,
    required String winLossText,
    required Color winLossColor,
    required AppLocalizations l10n,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (displayRank == 1) Icon(Icons.emoji_events, size: 36, color: amberAccent),
              if (displayRank == 2) Icon(Icons.emoji_events, size: 36, color: Colors.grey[400]),
              if (displayRank == 3) Icon(Icons.emoji_events, size: 36, color: Colors.amber[800]),
              if (displayRank > 3) Icon(Icons.military_tech, size: 36, color: primaryIndigo.withValues(alpha: 0.5)),
              Positioned(
                bottom: 2,
                child: Text(
                  '$displayRank',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: displayRank <= 3 ? Colors.black87 : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              if (codeSubtitle != null) ...[
                const SizedBox(height: 4),
                Text(codeSubtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
              ],
            ],
          ),
        ),
        Column(
          children: [
            Text(l10n.winLoss, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey[500], letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(winLossText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: winLossColor)),
          ],
        ),
        const SizedBox(width: 24),
        Column(
          children: [
            Text(l10n.rollingVolume, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey[500], letterSpacing: 1)),
            const SizedBox(height: 4),
            Text('₱${_fmt.format(item.rolling)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        const SizedBox(width: 24),
        Column(
          children: [
            Text(l10n.commission, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey[500], letterSpacing: 1)),
            const SizedBox(height: 4),
            Text('₱${_fmt.format(item.commission)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ],
    );
  }

  Widget _buildSkeletonContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderWithFilters(context, l10n),
        const SizedBox(height: 24),
        ...List.generate(5, (_) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: const Row(
                children: [
                  SkeletonBox(width: 48, height: 48, borderRadius: 12),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: 18, width: 160, borderRadius: 4),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            SkeletonBox(height: 12, width: 60, borderRadius: 4),
                            SizedBox(width: 16),
                            SkeletonBox(height: 12, width: 60, borderRadius: 4),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SkeletonBox(height: 20, width: 80, borderRadius: 4),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
