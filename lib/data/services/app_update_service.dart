import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:smart_wallet/ui/core/theme.dart';

/// Checks Google Play for a newer published version and, if one is available,
/// shows a popup offering to update via Android's In-App Update flow.
///
/// This only does anything on Android for builds installed from the Play Store
/// (or Play internal app sharing / testing tracks). Everywhere else — debug
/// runs, sideloaded APKs, or iOS — it is a silent no-op, so it's safe to call
/// unconditionally on startup.
class AppUpdateService {
  /// Guards against re-prompting on every rebuild; we only check once per launch.
  static bool _checkedThisSession = false;

  /// Call once after the main UI is visible. Shows the update popup if a newer
  /// version is live on Play; otherwise returns without any UI.
  static Future<void> checkAndPrompt(BuildContext context) async {
    if (_checkedThisSession || !Platform.isAndroid) return;
    _checkedThisSession = true;

    final AppUpdateInfo info;
    try {
      info = await InAppUpdate.checkForUpdate();
    } catch (_) {
      // Not installed from Play, no Play services, or offline — ignore quietly.
      return;
    }

    if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
    if (!context.mounted) return;

    final wantsUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.system_update_rounded,
            color: AppColors.primary, size: 40),
        title: const Text('Update available'),
        content: const Text(
          'A new version of Smart Wallet is available on the Play Store. '
          'Update now to get the latest features and fixes.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Later',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (wantsUpdate != true) return;

    try {
      // Prefer a flexible (background) download when Play allows it so the user
      // isn't blocked; once downloaded, complete it (which restarts the app).
      // Fall back to the full-screen immediate flow otherwise.
      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      } else {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (_) {
      // User cancelled the system update flow or it failed — keep using the app.
    }
  }
}
