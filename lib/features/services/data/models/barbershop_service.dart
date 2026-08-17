import 'package:cloud_firestore/cloud_firestore.dart';

class BarbershopService {
  final String id;
  final String name;
  final String description;
  final int priceCents;
  final int durationMinutes;
  final bool active;
  final int order;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BarbershopService({
    required this.id,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.durationMinutes,
    required this.active,
    required this.order,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BarbershopService.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    final rawImageUrl = data['imageUrl'] as String?;

    return BarbershopService(
      id: document.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      priceCents: (data['priceCents'] as num?)?.toInt() ?? 0,
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 0,
      active: data['active'] as bool? ?? false,
      order: (data['order'] as num?)?.toInt() ?? 0,
      imageUrl: rawImageUrl != null && rawImageUrl.trim().isNotEmpty
          ? rawImageUrl.trim()
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
