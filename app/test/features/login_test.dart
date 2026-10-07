import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zzinhugi/features/login/login_screen.dart';

import '../helpers.dart';

void main() {
  testWidgets('닉네임을 입력하고 테스트 로그인하면 인증 서비스에 전달', (tester) async {
    final auth = FakeAuth(null);
    await tester.pumpWidget(harness(child: const LoginScreen(), backend: FakeBackend(), auth: auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '찐테스터');
    await tester.tap(find.text('테스트 로그인'));
    await tester.pumpAndSettle();

    expect(auth.lastNickname, '찐테스터');
  });

  testWidgets('닉네임이 비어 있으면 로그인하지 않음', (tester) async {
    final auth = FakeAuth(null);
    await tester.pumpWidget(harness(child: const LoginScreen(), backend: FakeBackend(), auth: auth));
    await tester.tap(find.text('테스트 로그인'));
    await tester.pump();
    expect(auth.lastNickname, isNull);
    expect(find.text('닉네임을 입력해 주세요'), findsOneWidget);
  });

  testWidgets('카카오·Apple 로그인은 준비 중 표시', (tester) async {
    await tester.pumpWidget(harness(child: const LoginScreen(), backend: FakeBackend(), auth: FakeAuth(null)));
    expect(find.text('카카오로 시작하기 (준비 중)'), findsOneWidget);
    expect(find.text('Apple로 시작하기 (준비 중)'), findsOneWidget);
  });
}
