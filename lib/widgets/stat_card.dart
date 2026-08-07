import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum StatCardColor { primary, purple, emerald, rose, amber, teal, brown }

class StatCard extends StatelessWidget {
  final String label;
  final String value;

  /// If set, this widget is shown instead of [value] text (e.g. for animated counter).
  final Widget? valueWidget;
  final String? subValue;
  final IconData icon;
  final StatCardColor color;
  final String? trendValue;
  final bool? trendIsUp;

  /// When true, enlarges icon/text and centers content in the card instead of anchoring top-left. Use for cards much taller than their content (e.g. a 3-column grid with a tall aspect ratio).
  final bool centered;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.valueWidget,
    this.subValue,
    required this.icon,
    this.color = StatCardColor.primary,
    this.trendValue,
    this.trendIsUp,
    this.centered = false,
  });

  Color get _colorValue {
    switch (color) {
      case StatCardColor.primary:
        return primaryIndigo;
      case StatCardColor.purple:
        return accentPurple;
      case StatCardColor.emerald:
        return emeraldAccent;
      case StatCardColor.rose:
        return roseAccent;
      case StatCardColor.amber:
        return amberAccent;
      case StatCardColor.teal:
        return tealAccent;
      case StatCardColor.brown:
        return brownAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            constraints.maxHeight < 90 || constraints.maxWidth < 140;
        // Tablet/mid size: mas malaki padding para hindi mukhang lubog ang text
        final isTabletSize =
            constraints.maxWidth >= 160 && constraints.maxWidth <= 320;
        final padding = isCompact ? 8.0 : (isTabletSize ? 14.0 : 14.0);
        final spacing = isCompact ? 4.0 : 8.0;
        final valueFontSize = isCompact ? 12.0 : (centered ? 24.0 : 18.0);
        final labelFontSize = isCompact ? 8.0 : (centered ? 18.0 : 9.0);
        final iconBoxSize = isCompact ? 3.0 : (centered ? 10.0 : 6.0);
        final iconSize = isCompact ? 12.0 : (centered ? 24.0 : 16.0);
        return Container(
          padding: EdgeInsets.all(padding),
          alignment: centered ? Alignment.center : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _colorValue.withValues(alpha: 0.3)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _colorValue.withValues(alpha: 0.2),
                _colorValue.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment:
                centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(iconBoxSize),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: iconSize, color: _colorValue),
                  ),
                  if (trendValue != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: (trendIsUp ?? true)
                              ? emeraldAccent.withValues(alpha: 0.2)
                              : roseAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${(trendIsUp ?? true) ? '+' : '-'}$trendValue',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: (trendIsUp ?? true)
                                ? emeraldAccent
                                : roseAccent,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: centered ? spacing * 1.5 : spacing),
              Padding(
                padding: centered
                    ? EdgeInsets.zero
                    : const EdgeInsets.only(right: 4),
                child: Text(
                  label.toUpperCase(),
                  textAlign: centered ? TextAlign.center : TextAlign.start,
                  style: TextStyle(
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: centered ? Colors.white : Colors.grey[400],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: centered ? 2 : 1,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: centered ? Alignment.center : Alignment.centerLeft,
                  child: Padding(
                    padding: centered
                        ? EdgeInsets.zero
                        : const EdgeInsets.only(right: 8),
                    child: DefaultTextStyle(
                      style: TextStyle(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      child: valueWidget ??
                          Text(
                            value,
                            maxLines: 1,
                          ),
                    ),
                  ),
                ),
              ),
              if (subValue != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subValue!,
                    textAlign: centered ? TextAlign.center : TextAlign.start,
                    style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
