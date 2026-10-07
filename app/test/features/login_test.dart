import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zzinhugi/data/auth_service.dart';
import 'package:zzinhugi/features/login/login_screen.dart';

import '../helpers.dart';

void tall(WidgetTester t) {
  t.view.physicalSize = const Size(800, 2000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('닉네임을 입력하고 테스트 로그인하면 인증 서비스에 전달', (tester) async {
    tall(tester);
    final auth = FakeAuth(null);
    await tester.pumpWidget(harness(child: const LoginScreen(), backend: FakeBackend(), auth: auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '찐테스터');
    await tester.tap(find.text('테스트 로그인'));
    await tester.pumpAndSettle();

    expect(auth.lastNickname, '찐테스터');
  });

  testWidgets('닉네임이 비어 있으면 로그인하지 않음', (tester) async {
    tall(tester);
    final auth = FakeAuth(null);
    await tester.pumpWidget(harness(child: const LoginScreen(), backend: FakeBackend(), auth: auth));
    await tester.tap(find.text('테스트 로그인'));
    await tester.pump();
    expect(auth.lastNickname, isNull);
    expect(find.text('닉네임을 입력해 주세요'), findsOneWidget);
  });

  testWidgets('카카오 로그인은 웹에서 활성, Apple 은 준비 중 표시', (tester) async {
    tall(tester);
    await tester.pumpWidget(harness(child: const LoginScreen(), backend: FakeBackend(), auth: FakeAuth(null)));
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.text('Apple로 시작하기 (준비 중)'), findsOneWidget);
  });

  testWidgets('카카오 버튼을 누르면 카카오 로그인 시작', (tester) async {
    tall(tester);
    final auth = FakeAuth(null);
    await tester.pumpWidget(harness(child: const LoginScreen(), backend: FakeBackend(), auth: auth));
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    expect(auth.kakaoCalls, 1);
  });

  testWidgets('카카오를 쓸 수 없는 환경이면 준비 중 안내', (tester) async {
    tall(tester);
    await tester.pumpWidget(harness(child: const LoginScreen(), backend: FakeBackend(), auth: FakeAuth(null, false)));
    expect(find.text('카카오로 시작하기 (준비 중)'), findsOneWidget);
  });

  testWidgets('카카오에서 돌아와 남긴 안내 문구를 보여 줌', (tester) async {
    tall(tester);
    loginNotice.value = '카카오 로그인을 취소했어요.';
    addTearDown(() => loginNotice.value = null);
    await tester.pumpWidget(harness(child: const LoginScreen(), backend: FakeBackend(), auth: FakeAuth(null)));
    expect(find.text('카카오 로그인을 취소했어요.'), findsOneWidget);
  });
}
