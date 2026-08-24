import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';

class JokarzCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const JokarzCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      decoration: BoxDecoration(
        color: backgroundColor ?? JokarzColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? JokarzColors.cardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class PokerChipButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isNegative;

  const PokerChipButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: JokarzColors.surfaceLight,
          shape: BoxShape.circle,
          border: Border.all(
            color: color,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(80),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerRankBadge extends StatelessWidget {
  final int rank;

  const PlayerRankBadge({super.key, required this.rank});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String badgeText;

    switch (rank) {
      case 1:
        badgeColor = JokarzColors.gold;
        badgeText = '👑 1st';
        break;
      case 2:
        badgeColor = const Color(0xFFCFD8DC);
        badgeText = '🥈 2nd';
        break;
      case 3:
        badgeColor = const Color(0xFFFFB74D);
        badgeText = '🥉 3rd';
        break;
      default:
        badgeColor = JokarzColors.textMuted;
        badgeText = '#$rank';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: badgeColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class LuxuryTrophyCard extends StatelessWidget {
  final String title;
  final String value;
  final String player;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;

  const LuxuryTrophyCard({
    super.key,
    required this.title,
    required this.value,
    required this.player,
    this.subtitle,
    required this.icon,
    this.accentColor = JokarzColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JokarzColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withAlpha(120), width: 1.2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            JokarzColors.surfaceLight,
            JokarzColors.card,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: JokarzColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            player,
            style: const TextStyle(
              color: JokarzColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                color: JokarzColors.textMuted,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
