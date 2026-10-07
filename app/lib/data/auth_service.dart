import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/env.dart';
import 'kakao_web.dart';

/// 로그인 화면에 한 번 보여 줄 안내(카카오에서 취소하고 돌아왔을 때 등). 보여 준 뒤 지운다.
final ValueNotifier<String?> loginNotice = ValueNotifier<String?>(null);

abstract class AuthService {
  String? get currentUid;
  Stream<String?> get uidChanges;

  /// 에뮬레이터 전용 테스트 로그인. 닉네임이 같으면 같은 계정으로 다시 로그인된다.
  Future<void> signInDebug(String nickname);

  /// 카카오 로그인을 쓸 수 있는 환경인지 (현재는 웹만).
  bool get supportsKakao;

  /// 카카오 로그인 화면으로 이동한다. 로그인이 끝나면 앱이 다시 열리고 [FirebaseAuthService.completeKakaoRedirect] 가 마무리한다.
  Future<void> signInKakao();

  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  static const _nickKey = 'debug_nickname';

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFunctions get _fn => FirebaseFunctions.instanceFor(region: functionsRegion);

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
    await _fn.httpsCallable('ensureUser').call();
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
  bool get supportsKakao => kIsWeb;

  @override
  Future<void> signInKakao() async {
    final state = _randomState();
    kakaoSaveState(state);
    // 카카오 인가 주소는 서버가 만든다(REST 키가 앱 번들에 들어가지 않게).
    final res = await _fn.httpsCallable('kakaoLoginUrl').call({'redirectUri': kakaoRedirectUri(), 'state': state});
    kakaoRedirectTo((res.data as Map)['url'] as String);
  }

  /// 앱이 시작될 때 부른다. 주소가 카카오에서 돌아온 것(`?code=…`)이면 로그인을 마무리한다.
  /// 카카오 로그인 복귀를 처리했으면(성공이든 실패든) true.
  Future<bool> completeKakaoRedirect() async {
    final p = kakaoReadParams();
    if (p == null) return false;
    kakaoCleanUrl();
    final saved = kakaoTakeState();
    if (p.error != null) {
      loginNotice.value = '카카오 로그인을 취소했어요.';
      return true;
    }
    if (p.code == null || p.state == null || p.state != saved) {
      loginNotice.value = '로그인 요청이 올바르지 않아요. 다시 시도해 주세요.';
      return true;
    }
    try {
      final res = await _fn.httpsCallable('kakaoLogin').call({'code': p.code, 'redirectUri': kakaoRedirectUri()});
      await _auth.signInWithCustomToken((res.data as Map)['token'] as String);
      await _fn.httpsCallable('ensureUser').call();
      // 이전 테스트 로그인 닉네임이 남아 있으면 다음 시작 때 그 계정으로 되돌아가므로 지운다.
      await (await SharedPreferences.getInstance()).remove(_nickKey);
      loginNotice.value = null;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('kakaoLogin 실패: ${e.code} ${e.message}');
      loginNotice.value = '카카오 로그인에 실패했어요. 잠시 후 다시 시도해 주세요.';
    } catch (e) {
      debugPrint('kakaoLogin 실패: $e');
      loginNotice.value = '카카오 로그인에 실패했어요. 잠시 후 다시 시도해 주세요.';
    }
    return true;
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await (await SharedPreferences.getInstance()).remove(_nickKey);
  }
}

String _randomState() {
  final r = Random.secure();
  return base64Url.encode(List<int>.generate(24, (_) => r.nextInt(256))).replaceAll('=', '');
}
