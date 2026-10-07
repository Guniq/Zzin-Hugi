/// `flutter run --dart-define=USE_EMULATOR=true` 일 때만 true.
const bool useEmulator = bool.fromEnvironment('USE_EMULATOR');
const String emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');
const String functionsRegion = 'asia-northeast3';

/// 카카오맵 JavaScript 키. `--dart-define=KAKAO_JS_KEY=...` (비어 있으면 지도 없이 목록 검색만 쓴다).
const String kakaoJsKey = String.fromEnvironment('KAKAO_JS_KEY');
