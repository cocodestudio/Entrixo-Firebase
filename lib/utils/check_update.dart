import 'package:flutter/cupertino.dart';
import 'package:in_app_update/in_app_update.dart';

class AppUpdateService {
  static Future<void> checkForUpdate() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.performImmediateUpdate().catchError((e) {
          debugPrint("Update failed: $e");
          return AppUpdateResult.inAppUpdateFailed;
        });
      }
    } catch (e) {
      debugPrint("In-App Update Error: $e (This is normal in Debug mode)");
    }
  }
}