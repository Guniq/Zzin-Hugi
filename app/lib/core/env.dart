/// `flutter run --dart-define=USE_EMULATOR=true` 일 때만 true.
const bool useEmulator = bool.fromEnvironment('USE_EMULATOR');
const String emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');
const String functionsRegion = 'asia-northeast3';
