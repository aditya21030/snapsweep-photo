import 'package:flutter/material.dart';
import '../../core/services/ad_service.dart';

Future<void> showOperationResult(
  BuildContext context, {
  required String message,
}) async {
  if (!context.mounted) return;

  // Immediately trigger interstitial ad upon operation completion without blocking dialog
  await AdService.showCompletionAd();

  // Show a lightweight floating confirmation toast
  if (context.mounted && message.isNotEmpty) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
