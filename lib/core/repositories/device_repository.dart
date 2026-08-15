import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:j2i_app_barbearia/core/models/registered_device.dart';
import 'package:j2i_app_barbearia/core/services/device_service.dart';

class DeviceRegistrationResult {
  final DeviceData device;
  final bool isNewDevice;
  final String status;

  const DeviceRegistrationResult({
    required this.device,
    required this.isNewDevice,
    required this.status,
  });

  bool get isActive => status == 'active';
}

class DeviceRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final DeviceService _deviceService;

  DeviceRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    DeviceService? deviceService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _deviceService = deviceService ?? DeviceService();

  Future<DeviceRegistrationResult> registerCurrentDevice() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Nenhum usuário autenticado.');
    }

    final device = await _deviceService.getCurrentDevice();

    debugPrint(
      'DEVICE -> '
      'installationId: ${device.installationId} | '
      'platform: ${device.platform} | '
      'model: ${device.model}',
    );

    final deviceReference = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(device.installationId);

    final snapshot = await deviceReference.get();

    if (!snapshot.exists) {
      await deviceReference.set({
        ...device.toMap(),
        'firstSeenAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      debugPrint('DEVICE STATUS -> NOVO DISPOSITIVO');

      return DeviceRegistrationResult(
        device: device,
        isNewDevice: true,
        status: 'active',
      );
    }

    final data = snapshot.data();

    final status = data?['status'] as String? ?? 'active';

    await deviceReference.update({
      'platform': device.platform,
      'manufacturer': device.manufacturer,
      'model': device.model,
      'osVersion': device.osVersion,
      'sdkInt': device.sdkInt,
      'isPhysicalDevice': device.isPhysicalDevice,
      'lastSeenAt': FieldValue.serverTimestamp(),
    });

    debugPrint('DEVICE STATUS -> DISPOSITIVO CONHECIDO');

    debugPrint('DEVICE STATUS -> $status');

    return DeviceRegistrationResult(
      device: device,
      isNewDevice: false,
      status: status,
    );
  }

  Future<String> getCurrentInstallationId() async {
    final device = await _deviceService.getCurrentDevice();

    return device.installationId;
  }

  Stream<List<RegisteredDevice>> watchDevices() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.error(Exception('Nenhum usuário autenticado.'));
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .orderBy('lastSeenAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(RegisteredDevice.fromFirestore).toList(),
        );
  }
}
