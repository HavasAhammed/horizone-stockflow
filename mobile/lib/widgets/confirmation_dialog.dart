import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.isDestructive = false,
  });

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText, style: const TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? AppColors.danger : AppColors.primaryBlue,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmText),
        ),
      ],
    );
  }
}
