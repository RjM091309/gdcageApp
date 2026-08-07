import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../generated/app_localizations.dart';
import '../models/types.dart';
import '../services/marker_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skeleton_box.dart';

final _fmt =
    NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);

class MarkerView extends StatefulWidget {
  const MarkerView({super.key});

  @override
  State<MarkerView> createState() => _MarkerViewState();
}

class _MarkerViewState extends State<MarkerView> {
  final MarkerService _service = MarkerService.instance;
  bool _loading = true;
  String? _error;
  List<MarkerEntry> _markers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.fetch();
      if (!mounted) return;
      setState(() {
        _markers = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load marker data';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading && _markers.isEmpty) {
      return _buildSkeletonContent(context);
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
    if (_markers.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: primaryIndigo, size: 20),
              const SizedBox(width: 8),
              Text(l10n.realTimeMarker,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const Spacer(),
              Text(l10n.totalMarker,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400])),
              const SizedBox(width: 8),
              Text(_fmt.format(0),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text('No marker / credit data',
                  style: TextStyle(fontSize: 15, color: Colors.grey[500])),
            ),
          ),
        ],
      );
    }
    final totalMarkerBalance =
        _markers.fold<int>(0, (sum, e) => sum + e.balance);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.description, color: primaryIndigo, size: 20),
            const SizedBox(width: 8),
            Text(l10n.realTimeMarker,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const Spacer(),
            Text(l10n.totalMarker,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400])),
            const SizedBox(width: 8),
            Text(_fmt.format(totalMarkerBalance),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 900
                ? 3
                : (constraints.maxWidth > 600 ? 2 : 1);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 1.55,
              ),
              itemCount: _markers.length,
              itemBuilder: (context, i) {
                final marker = _markers[i];
                final hasLimit = marker.limit > 0;
                final usagePercent =
                    hasLimit ? (marker.balance / marker.limit) * 100 : 0.0;
                return _CreditStyleCard(
                  marker: marker,
                  hasLimit: hasLimit,
                  usagePercent: usagePercent,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSkeletonContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            SkeletonBox(width: 20, height: 20, borderRadius: 6),
            SizedBox(width: 8),
            SkeletonBox(width: 180, height: 20, borderRadius: 4),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 900
                ? 3
                : (constraints.maxWidth > 600 ? 2 : 1);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.95,
              ),
              itemCount: 6,
              itemBuilder: (context, i) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SkeletonBox(width: 40, height: 30, borderRadius: 6),
                          SkeletonBox(width: 32, height: 24, borderRadius: 4),
                        ],
                      ),
                      SkeletonBox(height: 14, width: 160, borderRadius: 4),
                      SizedBox(height: 12),
                      SkeletonBox(height: 18, width: 140, borderRadius: 4),
                      SizedBox(height: 8),
                      SkeletonBox(height: 28, width: 100, borderRadius: 4),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Credit-card style marker/credit card.
class _CreditStyleCard extends StatelessWidget {
  const _CreditStyleCard({
    required this.marker,
    required this.hasLimit,
    required this.usagePercent,
  });

  final MarkerEntry marker;
  final bool hasLimit;
  final double usagePercent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1B2E),
            const Color(0xFF2D2640),
            primaryIndigo.withValues(alpha: 0.15),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Subtle shine line (credit card gloss)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Right watermark logo (low opacity), slightly left of right edge
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0.85, 0),
                child: Opacity(
                  opacity: 0.12,
                  child: Image.asset(
                    'assets/images/logoOnly.png',
                    width: 140,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top row: logo (left) + date/time & Agent (right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox.shrink(),
                      // Date/time + Agent (right column)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (marker.lastUpdate.isNotEmpty)
                            Text(
                              marker.lastUpdate,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (marker.guest.isNotEmpty) ...[
                            if (marker.lastUpdate.isNotEmpty)
                              const SizedBox(height: 4),
                            Text(
                              'Agent : ${marker.guest}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Card number style (masked)
                  Text(
                    '••••  ••••  ••••  ${(marker.balance.abs() % 10000).toString().padLeft(4, '0')}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Cardholder name (agent NAME (CODE))
                  Text(
                    marker.agent,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Balance row + chip (bottom right, chip inline center)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.activeBalance,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.5),
                                letterSpacing: 1),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _fmt.format(marker.balance),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: marker.balance >= 0
                                  ? Colors.white
                                  : roseAccent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (hasLimit)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    l10n.limit,
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                        letterSpacing: 1),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _fmt.format(marker.limit),
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white
                                            .withValues(alpha: 0.7)),
                                  ),
                                ],
                              ),
                            ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/ccChips.png',
                              width: 56,
                              height: 42,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (hasLimit) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (usagePercent / 100).clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation(
                                  usagePercent > 80
                                      ? roseAccent
                                      : accentPurple),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${usagePercent.toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: usagePercent > 80
                                  ? roseAccent
                                  : accentPurple),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
