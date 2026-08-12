import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:j2i_app_barbearia/core/errors/auth_exceptions.dart';
import 'package:j2i_app_barbearia/core/utils/cpf_validator.dart';
import 'package:j2i_app_barbearia/features/auth/data/models/user_profile.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  // USUÁRIO ATUAL
  User? get currentUser => _auth.currentUser;

  // MONITORA LOGIN E LOGOUT
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  // MONITORA ALTERAÇÕES DO USUÁRIO
  Stream<User?> userChanges() {
    return _auth.userChanges();
  }

  // ENVIA E-MAIL DE VERIFICAÇÃO
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Nenhum usuário autenticado.');
    }

    if (user.emailVerified) {
      return;
    }

    await _auth.setLanguageCode('pt-BR');
    await user.sendEmailVerification();
  }

  // ATUALIZA OS DADOS DO USUÁRIO
  Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  // CADASTRO
  Future<void> register({
    required String name,
    required String cpf,
    required String email,
    required String phone,
    required String password,
  }) async {
    final normalizedCpf = CpfValidator.normalize(cpf);

    if (!CpfValidator.isValid(normalizedCpf)) {
      throw const InvalidCpfException();
    }

    UserCredential? credential;

    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Não foi possível criar o usuário.');
      }

      await user.updateDisplayName(name.trim());

      final profile = UserProfile(
        uid: user.uid,
        name: name.trim(),
        cpf: normalizedCpf,
        email: email.trim().toLowerCase(),
        phone: phone.trim(),
        role: 'client',
        createdAt: Timestamp.now(),
      );

      final userReference = _firestore.collection('users').doc(user.uid);

      final cpfReference = _firestore
          .collection('cpf_registry')
          .doc(normalizedCpf);

      final batch = _firestore.batch();

      batch.set(cpfReference, {
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(userReference, profile.toMap());

      try {
        await batch.commit();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          throw const CpfAlreadyInUseException();
        }

        rethrow;
      }
    } catch (e) {
      if (credential?.user != null) {
        try {
          await credential!.user!.delete();
        } catch (_) {}
      }

      rethrow;
    }
  }

  // LOGIN
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  // LOGOUT
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // RECUPERAÇÃO DE SENHA
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }
}
