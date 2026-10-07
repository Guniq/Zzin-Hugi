import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// 웹 Firebase SDK가 저장해 둔 로그인 세션(IndexedDB)을 SDK가 켜지기 전에 지운다.
/// 에뮬레이터 모드에서 SDK가 세션 복원 요청을 실서버로 보내 버리는 문제를 피하기 위함이다.
Future<void> resetAuthStore() {
  final done = Completer<void>();
  void finish(web.Event _) {
    if (!done.isCompleted) done.complete();
  }

  final req = web.window.indexedDB.deleteDatabase('firebaseLocalStorageDb');
  req.onsuccess = finish.toJS;
  req.onerror = finish.toJS;
  req.onblocked = finish.toJS;
  return done.future;
}
