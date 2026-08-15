import 'package:cloud_firestore/cloud_firestore.dart';

class RegisteredDevice {
  final String id;
  final String installationId;
  final String platform;
  final String manufacturer;
  final String model;
  final String osVersion;
  final int? sdkInt;
  final bool isPhysicalDevice;
  final String status;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;

  const RegisteredDevice({
    required this.id,
    required this.installationId,
    required this.platform,
    required this.manufacturer,
    required this.model,
    required this.osVersion,
    required this.sdkInt,
    required this.isPhysicalDevice,
    required this.status,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });

  factory RegisteredDevice.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return RegisteredDevice(
      id: document.id,
      installationId: data['installationId'] as String? ?? document.id,
      platform: data['platform'] as String? ?? 'unknown',
      manufacturer: data['manufacturer'] as String? ?? 'Desconhecido',
      model: data['model'] as String? ?? 'Desconhecido',
      osVersion: data['osVersion'] as String? ?? 'Desconhecido',
      sdkInt: data['sdkInt'] as int?,
      isPhysicalDevice: data['isPhysicalDevice'] as bool? ?? false,
      status: data['status'] as String? ?? 'active',
      firstSeenAt: (data['firstSeenAt'] as Timestamp?)?.toDate(),
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate(),
    );
  }
}
