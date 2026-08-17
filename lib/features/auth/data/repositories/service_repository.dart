import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:j2i_app_barbearia/features/services/data/models/barbershop_service.dart';

class ServiceRepository {
  final FirebaseFirestore _firestore;

  ServiceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<BarbershopService>> watchActiveServices() {
    return _firestore
        .collection('services')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final services = snapshot.docs
              .map(BarbershopService.fromDocument)
              .toList();

          services.sort((a, b) {
            final orderComparison = a.order.compareTo(b.order);

            if (orderComparison != 0) {
              return orderComparison;
            }

            return a.name.compareTo(b.name);
          });

          return services;
        });
  }
}
