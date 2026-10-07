import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjinhugi/domain/models.dart';
import 'package:jjinhugi/features/profile/profile_screen.dart';

import '../helpers.dart';

Restaurant rest(String id, String name) => Restaurant(id: id, name: name, address: '서울', region: 'seongsu');

FakeBackend backend() => FakeBackend()
  ..restaurants = [rest('a', '가게A'), rest('b', '가게B'), rest('c', '가게C')]
  ..users = {
    'seed1': AppUser.fromMap('seed1', {
      'nickname': '찐미식가', 'title': '찐후기러', 'likesReceived': 16, 'verifiedReviewCount': 3,
      'ranking': {'best': ['a', 'b'], 'ok': ['c'], 'bad': []},
    }),
  };

void main() {
  testWidgets('닉네임·칭호·받은 따봉', (tester) async {
    await tester.pumpWidget(harness(child: const ProfileScreen(uid: 'seed1'), backend: backend()));
    await tester.pumpAndSettle();
    expect(find.text('찐미식가'), findsOneWidget);
    expect(find.text('찐후기러'), findsOneWidget);
    expect(find.text('받은 따봉 16'), findsOneWidget);
  });

  testWidgets('최고 탭: 순위와 개인 점수 (백엔드와 같은 공식)', (tester) async {
    await tester.pumpWidget(harness(child: const ProfileScreen(uid: 'seed1'), backend: backend()));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('가게A'), findsOneWidget);
    expect(find.text('9.3'), findsOneWidget);
    expect(find.text('가게B'), findsOneWidget);
    expect(find.text('7.8'), findsOneWidget);
  });

  testWidgets('괜찮 탭으로 전환', (tester) async {
    await tester.pumpWidget(harness(child: const ProfileScreen(uid: 'seed1'), backend: backend()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('괜찮'));
    await tester.pumpAndSettle();
    expect(find.text('가게C'), findsOneWidget);
    expect(find.text('5.5'), findsOneWidget);
  });

  testWidgets('비어 있는 등급은 안내', (tester) async {
    await tester.pumpWidget(harness(child: const ProfileScreen(uid: 'seed1'), backend: backend()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('별로'));
    await tester.pumpAndSettle();
    expect(find.text('아직 없어요'), findsOneWidget);
  });

  testWidgets('식당을 누르면 상세로', (tester) async {
    await tester.pumpWidget(harness(child: const ProfileScreen(uid: 'seed1'), backend: backend()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('가게A'));
    await tester.pumpAndSettle();
    expect(find.text('detail:a'), findsOneWidget);
  });

  testWidgets('본인 프로필에만 로그아웃 버튼', (tester) async {
    final b = backend()..users['me'] = appUser('me');
    final auth = FakeAuth('me');
    await tester.pumpWidget(harness(child: const ProfileScreen(uid: 'me'), backend: b, auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(auth.signedOut, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(harness(child: const ProfileScreen(uid: 'seed1'), backend: backend(), auth: FakeAuth('me')));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃'), findsNothing);
  });

  testWidgets('없는 유저는 안내', (tester) async {
    await tester.pumpWidget(harness(child: const ProfileScreen(uid: 'ghost'), backend: FakeBackend()));
    await tester.pumpAndSettle();
    expect(find.text('프로필을 찾을 수 없어요'), findsOneWidget);
  });
}
