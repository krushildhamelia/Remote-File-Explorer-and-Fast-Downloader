
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> grantAllAndroidPermissions() async {
  // INTERNET and ACCESS_WIFI_STATE are normal permissions -> automatically granted
  // No runtime request needed for those

  // Storage permissions
  if (Platform.isAndroid) {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

    if (androidInfo.version.sdkInt >= 30) {
      // Android 11+ : MANAGE_EXTERNAL_STORAGE
      bool hasAllFilesAccess = await Permission.manageExternalStorage.isGranted;
      await Permission.manageExternalStorage.request();
      // await Permission.accessMediaLocation.request();
      if (!hasAllFilesAccess) {
        final intent = AndroidIntent(
          action: 'android.settings.MANAGE_ALL_FILES_ACCESS_PERMISSION',
        );
        await intent.launch();
        return; // User must grant manually in settings
      }
    } else {
      // Android 10 and below: READ/WRITE storage
      if (!await Permission.storage.isGranted) {
        await Permission.storage.request();
      }
    }
  }
}
