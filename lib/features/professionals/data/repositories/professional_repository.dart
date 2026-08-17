import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:j2i_app_barbearia/features/professionals/data/models/professional.dart';

class ProfessionalRepository {
  final FirebaseFirestore _firestore;

  ProfessionalRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<Professional>> watchActiveProfessionalsForService(
    String serviceId,
  ) {
    return _firestore
        .collection('professionals')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final professionals = snapshot.docs
              .map(Professional.fromDocument)
              .where((professional) {
                // Lista vazia significa que
                // o profissional atende todos
                // os serviços.
                return professional.serviceIds.isEmpty ||
                    professional.serviceIds.contains(serviceId);
              })
              .toList();

          professionals.sort((a, b) {
            final orderComparison = a.order.compareTo(b.order);

            if (orderComparison != 0) {
              return orderComparison;
            }

            return a.name.compareTo(b.name);
          });

          return professionals;
        });
  }
}
