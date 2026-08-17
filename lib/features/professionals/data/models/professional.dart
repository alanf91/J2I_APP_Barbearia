import 'package:cloud_firestore/cloud_firestore.dart';

class Professional {
  final String id;
  final String name;
  final String specialty;
  final bool active;
  final int order;
  final List<String> serviceIds;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Professional({
    required this.id,
    required this.name,
    required this.specialty,
    required this.active,
    required this.order,
    required this.serviceIds,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Professional.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    final rawServiceIds = data['serviceIds'] as List<dynamic>? ?? [];

    final rawImageUrl = data['imageUrl'] as String?;

    return Professional(
      id: document.id,
      name: data['name'] as String? ?? '',
      specialty: data['specialty'] as String? ?? '',
      active: data['active'] as bool? ?? false,
      order: (data['order'] as num?)?.toInt() ?? 0,
      serviceIds: rawServiceIds.whereType<String>().toList(),
      imageUrl: rawImageUrl != null && rawImageUrl.trim().isNotEmpty
          ? rawImageUrl.trim()
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
