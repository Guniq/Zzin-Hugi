import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/env.dart';

abstract class AuthService {
  String? get currentUid;
  Stream<String?> get uidChanges;

  /// 에뮬레이터 전용 테스트 로그인. 닉네임이 같으면 같은 계정으로 다시 로그인된다.
  Future<void> signInDebug(String nickname);
  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Stream<String?> get uidChanges => _auth.authStateChanges().map((u) => u?.uid);

  @override
  Future<void> signInDebug(String nickname) async {
    final email = '${base64Url.encode(utf8.encode(nickname)).replaceAll('=', '')}@debug.jjinhugi.test';
    const password = 'debug-pass-1234';
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found' && e.code != 'invalid-credential') rethrow;
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
    }
    await _auth.currentUser!.updateDisplayName(nickname);
    await _auth.currentUser!.getIdToken(true);
    await FirebaseFunctions.instanceFor(region: functionsRegion).httpsCallable('ensureUser').call();
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
