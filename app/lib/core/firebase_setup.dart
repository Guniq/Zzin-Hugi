import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'env.dart';

const _demoOptions = FirebaseOptions(
  apiKey: 'demo-key',
  appId: '1:1:web:demo',
  messagingSenderId: '1',
  projectId: 'demo-jjinhugi',
  storageBucket: 'demo-jjinhugi.appspot.com',
);

Future<void> initFirebase() async {
  if (!useEmulator) {
    throw UnsupportedError('실제 Firebase 프로젝트 연결은 플랜 3에서 추가됩니다. --dart-define=USE_EMULATOR=true 로 실행하세요.');
  }
  await Firebase.initializeApp(options: _demoOptions);
  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
  await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
  FirebaseFunctions.instanceFor(region: functionsRegion).useFunctionsEmulator(emulatorHost, 5001);
}
