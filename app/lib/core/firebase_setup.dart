import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../data/auth_service.dart';
import 'env.dart';
import 'reset_auth_store.dart';

const _demoOptions = FirebaseOptions(
  apiKey: 'demo-key',
  appId: '1:1:web:demo',
  messagingSenderId: '1',
  projectId: 'demo-zzinhugi',
  storageBucket: 'demo-zzinhugi.appspot.com',
);

Future<void> initFirebase() async {
  if (!useEmulator) {
    throw UnsupportedError('실제 Firebase 프로젝트 연결은 플랜 3에서 추가됩니다. --dart-define=USE_EMULATOR=true 로 실행하세요.');
  }
  // 웹 SDK는 저장된 세션을 복원하느라 네트워크를 먼저 쓰면 이후 useAuthEmulator 가 적용되지 않는다.
  // 그래서 SDK가 켜지기 전에 저장된 세션을 지우고, 대신 닉네임 재로그인(restoreDebugSession)을 쓴다.
  await resetAuthStore();
  await Firebase.initializeApp(options: _demoOptions);
  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
  await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
  FirebaseFunctions.instanceFor(region: functionsRegion).useFunctionsEmulator(emulatorHost, 5001);
  final auth = FirebaseAuthService();
  try {
    // 카카오에서 돌아온 주소(?code=…)면 로그인을 마무리하고, 아니면 마지막 테스트 로그인을 복원한다.
    if (!await auth.completeKakaoRedirect()) await auth.restoreDebugSession();
  } catch (e) {
    // 복원에 실패하면 로그인 화면에서 다시 로그인하면 된다.
    debugPrint('restoreDebugSession 실패: $e');
  }
}
