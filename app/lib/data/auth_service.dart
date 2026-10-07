import 'dart:convert';


import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/env.dart';

abstract class AuthService {
  String? get currentUid;
  Stream<String?> get uidChanges;

  /// 에뮬레이터 전용 테스트 로그인. 닉네임이 같으면 같은 계정으로 다시 로그인된다.
  Future<void> signInDebug(String nickname);
  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  static const _nickKey = 'debug_nickname';

  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Stream<String?> get uidChanges => _auth.authStateChanges().map((u) => u?.uid);

  @override
  Future<void> signInDebug(String nickname) async {
    final email = '${base64Url.encode(utf8.encode(nickname)).replaceAll('=', '')}@debug.zzinhugi.test';
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
    await (await SharedPreferences.getInstance()).setString(_nickKey, nickname);
  }

  /// 에뮬레이터 전용 보완. 웹 SDK는 재시작 때 세션 복원 요청을 에뮬레이터가 연결되기 전에
  /// 실서버로 보내 400을 받고 로그아웃시킨다. 그래서 마지막 테스트 로그인 닉네임으로 다시 로그인한다.
  Future<void> restoreDebugSession() async {
    await _auth.authStateChanges().first;
    if (_auth.currentUser != null) return;
    final nick = (await SharedPreferences.getInstance()).getString(_nickKey);
    if (nick != null) await signInDebug(nick);
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await (await SharedPreferences.getInstance()).remove(_nickKey);
  }
}
