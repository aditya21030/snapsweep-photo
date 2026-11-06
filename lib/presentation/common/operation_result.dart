import 'package:flutter/material.dart';
import '../../core/services/ad_service.dart';

Future<void> showOperationResult(
  BuildContext context, {
  required String message,
}) async {
  if (!context.mounted) return;
  await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Completed'),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  // Trigger completion ad regardless of whether user tapped Continue or dismissed
  if (context.mounted) {
    await AdService.showCompletionAd();
  }
}
