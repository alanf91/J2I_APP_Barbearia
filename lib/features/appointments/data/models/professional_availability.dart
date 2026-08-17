import 'package:cloud_firestore/cloud_firestore.dart';

class ProfessionalAvailability {
  final String weekdayId;
  final bool enabled;
  final int startMinutes;
  final int endMinutes;
  final int intervalMinutes;

  const ProfessionalAvailability({
    required this.weekdayId,
    required this.enabled,
    required this.startMinutes,
    required this.endMinutes,
    required this.intervalMinutes,
  });

  factory ProfessionalAvailability.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return ProfessionalAvailability(
      weekdayId: document.id,
      enabled: data['enabled'] as bool? ?? false,
      startMinutes: (data['startMinutes'] as num?)?.toInt() ?? 0,
      endMinutes: (data['endMinutes'] as num?)?.toInt() ?? 0,
      intervalMinutes: (data['intervalMinutes'] as num?)?.toInt() ?? 30,
    );
  }
}
