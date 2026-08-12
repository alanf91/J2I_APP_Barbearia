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

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  Stream<User?> userChanges() {
    return _auth.userChanges();
  }

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

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

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

  Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  Future<String?> getRegisteredPhone() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final document = await _firestore.collection('users').doc(user.uid).get();

    final data = document.data();

    if (data == null) {
      return null;
    }

    return data['phone'] as String?;
  }

  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(PhoneAuthCredential credential)
    verificationCompleted,
    required void Function(FirebaseAuthException exception) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    await _auth.setLanguageCode('pt-BR');

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      forceResendingToken: forceResendingToken,
      timeout: const Duration(seconds: 60),
    );
  }

  Future<void> linkPhoneCredential(PhoneAuthCredential credential) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Nenhum usuário autenticado.');
    }

    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      return;
    }

    await user.linkWithCredential(credential);

    await user.reload();
  }

  Future<void> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    await linkPhoneCredential(credential);
  }
}
