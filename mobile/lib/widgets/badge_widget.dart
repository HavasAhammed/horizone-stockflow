import 'package:flutter/material.dart';
import '../core/app_colors.dart';

enum BadgeType { success, warning, danger, info, neutral }

class BadgeWidget extends StatelessWidget {
  final String text;
  final BadgeType type;

  const BadgeWidget({
    super.key,
    required this.text,
    this.type = BadgeType.neutral,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (type) {
      case BadgeType.success:
        bg = AppColors.solarGreenLight;
        fg = AppColors.solarGreenDark;
        break;
      case BadgeType.warning:
        bg = AppColors.solarAmberLight;
        fg = AppColors.solarAmber;
        break;
      case BadgeType.danger:
        bg = AppColors.dangerLight;
        fg = AppColors.danger;
        break;
      case BadgeType.info:
        bg = AppColors.primaryBlueLight;
        fg = AppColors.primaryBlue;
        break;
      case BadgeType.neutral:
        bg = const Color(0xFFF1F5F9);
        fg = AppColors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
