import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/app_update_service.dart';

class UpdateAvailableScreen extends StatelessWidget {
  const UpdateAvailableScreen({super.key, required this.controller});
  final AppUpdateController controller;
  @override
  Widget build(BuildContext context) {
    final checking = controller.stage == UpdateStage.checking;
    final required = controller.stage == UpdateStage.required;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/app_icon_new.png', width: 80, height: 80),
                  const SizedBox(height: 36),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: const BoxDecoration(
                      color: AppColors.lilac,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      checking
                          ? Icons.sync_rounded
                          : required
                          ? Icons.system_update_rounded
                          : Icons.cloud_off_rounded,
                      color: AppColors.violet,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    checking
                        ? 'Checking for updates'
                        : required
                        ? 'New update available'
                        : 'Couldn’t check for updates',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    checking
                        ? 'Making sure your SnapSweep is up to date.'
                        : required
                        ? 'Install the latest version of SnapSweep to continue. Your gallery and saved purchases will stay with you.'
                        : 'SnapSweep needs to confirm you have the latest version before opening.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      height: 1.6,
                      fontSize: 16,
                    ),
                  ),
                  if (controller.message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          controller.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  if (checking || controller.updating) ...[
                    const CircularProgressIndicator(),
                    if (controller.updating)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text('Follow the update steps in Google Play.'),
                      ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: required
                            ? controller.update
                            : controller.check,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: Text(required ? 'Update now' : 'Try again'),
                      ),
                    ),
                    TextButton(
                      onPressed: controller.openStore,
                      child: const Text('Open Google Play'),
                    ),
                    if (required)
                      TextButton(
                        onPressed: controller.check,
                        child: const Text('Check again'),
                      ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Updates are required to use SnapSweep.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
