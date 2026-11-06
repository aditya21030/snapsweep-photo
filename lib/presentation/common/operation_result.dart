import 'package:flutter/material.dart';
import '../../core/services/ad_service.dart';

Future<void> showOperationResult(
  BuildContext context, {
  required String message,
}) async {
  if (!context.mounted) return;
  final continueTapped = await showDialog<bool>(
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
  // Back or an outside tap dismisses the result without triggering an ad.
  if (continueTapped == true && context.mounted) {
    await AdService.showCompletionAd();
  }
}
