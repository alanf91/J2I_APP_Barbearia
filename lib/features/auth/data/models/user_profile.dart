import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String name;
  final String cpf;
  final String email;
  final String phone;
  final String role;
  final Timestamp createdAt;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.cpf,
    required this.email,
    required this.phone,
    required this.role,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'cpf': cpf,
      'email': email,
      'phone': phone,
      'role': role,
      'createdAt': createdAt,
    };
  }
}
