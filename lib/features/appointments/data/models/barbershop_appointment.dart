import 'package:cloud_firestore/cloud_firestore.dart';

class BarbershopAppointment {
  final String id;

  final String userId;

  final String serviceId;
  final String serviceName;

  final String professionalId;
  final String professionalName;

  final String dateKey;

  final int startMinutes;
  final int endMinutes;
  final int durationMinutes;
  final int priceCents;

  final String status;

  final DateTime startAt;
  final DateTime endAt;

  final DateTime? createdAt;

  const BarbershopAppointment({
    required this.id,
    required this.userId,
    required this.serviceId,
    required this.serviceName,
    required this.professionalId,
    required this.professionalName,
    required this.dateKey,
    required this.startMinutes,
    required this.endMinutes,
    required this.durationMinutes,
    required this.priceCents,
    required this.status,
    required this.startAt,
    required this.endAt,
    required this.createdAt,
  });

  factory BarbershopAppointment.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    final startTimestamp = data['startAt'] as Timestamp?;

    final endTimestamp = data['endAt'] as Timestamp?;

    final createdTimestamp = data['createdAt'] as Timestamp?;

    return BarbershopAppointment(
      id: document.id,

      userId: data['userId'] as String? ?? '',

      serviceId: data['serviceId'] as String? ?? '',

      serviceName: data['serviceName'] as String? ?? 'Serviço',

      professionalId: data['professionalId'] as String? ?? '',

      professionalName: data['professionalName'] as String? ?? 'Profissional',

      dateKey: data['dateKey'] as String? ?? '',

      startMinutes: (data['startMinutes'] as num?)?.toInt() ?? 0,

      endMinutes: (data['endMinutes'] as num?)?.toInt() ?? 0,

      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 0,

      priceCents: (data['priceCents'] as num?)?.toInt() ?? 0,

      status: data['status'] as String? ?? 'unknown',

      startAt:
          startTimestamp?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),

      endAt: endTimestamp?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),

      createdAt: createdTimestamp?.toDate(),
    );
  }
}
