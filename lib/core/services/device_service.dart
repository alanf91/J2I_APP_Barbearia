import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_app_installations/firebase_app_installations.dart';

class DeviceData {
  final String installationId;
  final String platform;
  final String manufacturer;
  final String model;
  final String osVersion;
  final int? sdkInt;
  final bool isPhysicalDevice;

  const DeviceData({
    required this.installationId,
    required this.platform,
    required this.manufacturer,
    required this.model,
    required this.osVersion,
    required this.sdkInt,
    required this.isPhysicalDevice,
  });

  Map<String, dynamic> toMap() {
    return {
      'installationId': installationId,
      'platform': platform,
      'manufacturer': manufacturer,
      'model': model,
      'osVersion': osVersion,
      'sdkInt': sdkInt,
      'isPhysicalDevice': isPhysicalDevice,
    };
  }
}

class DeviceService {
  final FirebaseInstallations _installations;
  final DeviceInfoPlugin _deviceInfo;

  DeviceService({
    FirebaseInstallations? installations,
    DeviceInfoPlugin? deviceInfo,
  }) : _installations = installations ?? FirebaseInstallations.instance,
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  Future<DeviceData> getCurrentDevice() async {
    final installationId = await _installations.getId();

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;

      return DeviceData(
        installationId: installationId,
        platform: 'android',
        manufacturer: androidInfo.manufacturer,
        model: androidInfo.model,
        osVersion: androidInfo.version.release,
        sdkInt: androidInfo.version.sdkInt,
        isPhysicalDevice: androidInfo.isPhysicalDevice,
      );
    }

    if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;

      return DeviceData(
        installationId: installationId,
        platform: 'ios',
        manufacturer: 'Apple',
        model: iosInfo.modelName,
        osVersion: '${iosInfo.systemName} ${iosInfo.systemVersion}',
        sdkInt: null,
        isPhysicalDevice: iosInfo.isPhysicalDevice,
      );
    }

    throw UnsupportedError('Plataforma não suportada.');
  }
}
