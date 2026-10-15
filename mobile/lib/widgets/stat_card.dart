import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtext;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtext,
    required this.icon,
    this.iconColor = AppColors.primaryBlue,
    this.iconBg = AppColors.primaryBlueLight,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
            if (subtext != null) ...[
              const SizedBox(height: 4),
              Text(
                subtext!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
