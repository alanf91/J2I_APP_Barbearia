import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:j2i_app_barbearia/features/appointments/data/models/professional_availability.dart';

class AvailabilityRepository {
  final FirebaseFirestore _firestore;

  AvailabilityRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<ProfessionalAvailability?> getAvailabilityForDate({
    required String professionalId,
    required DateTime date,
  }) async {
    final weekdayId = _weekdayId(date.weekday);

    final document = await _firestore
        .collection('professionals')
        .doc(professionalId)
        .collection('availability')
        .doc(weekdayId)
        .get();

    if (!document.exists) {
      return null;
    }

    return ProfessionalAvailability.fromDocument(document);
  }

  String _weekdayId(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'monday';

      case DateTime.tuesday:
        return 'tuesday';

      case DateTime.wednesday:
        return 'wednesday';

      case DateTime.thursday:
        return 'thursday';

      case DateTime.friday:
        return 'friday';

      case DateTime.saturday:
        return 'saturday';

      case DateTime.sunday:
        return 'sunday';

      default:
        throw ArgumentError('Dia da semana inválido.');
    }
  }
}
