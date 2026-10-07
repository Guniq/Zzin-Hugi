import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zzinhugi/domain/models.dart';
import 'package:zzinhugi/features/home/home_screen.dart';

import '../helpers.dart';

Restaurant r(String id, String name, {double? real, double? event, double? bubble, int count = 0}) => Restaurant(
      id: id, name: name, address: '서울 성동구 성수동2가 1', region: 'seongsu',
      realScore: real, eventScore: event, bubble: bubble, reviewCount: count,
    );

void main() {
  testWidgets('식당 카드: 찐점수·이벤트점수·거품지수·후기 수', (tester) async {
    final b = FakeBackend()
      ..restaurants = [r('a', '성수 찐고기', real: 2.3, event: 10, bubble: 7.7, count: 3)];
    await tester.pumpWidget(harness(child: const HomeScreen(), backend: b));
    await tester.pumpAndSettle();

    expect(find.text('성수 찐고기'), findsOneWidget);
    expect(find.text('찐점수'), findsOneWidget);
    expect(find.text('2.3'), findsOneWidget);
    expect(find.text('이벤트 10.0'), findsOneWidget);
    expect(find.text('거품 +7.7'), findsOneWidget);
    expect(find.text('후기 3'), findsOneWidget);
  });

  testWidgets('데이터 부족 표시', (tester) async {
    final b = FakeBackend()..restaurants = [r('a', '신상 식당', count: 1)];
    await tester.pumpWidget(harness(child: const HomeScreen(), backend: b));
    await tester.pumpAndSettle();

    expect(find.text('데이터 부족'), findsOneWidget);
    expect(find.textContaining('거품 +'), findsNothing);
  });

  testWidgets('목록이 비면 안내 문구', (tester) async {
    await tester.pumpWidget(harness(child: const HomeScreen(), backend: FakeBackend()));
    await tester.pumpAndSettle();
    expect(find.text('아직 후기가 없어요. 첫 찐후기를 남겨 보세요!'), findsOneWidget);
  });

  testWidgets('카드를 누르면 상세로 이동', (tester) async {
    final b = FakeBackend()..restaurants = [r('a', '성수 찐국밥', real: 7.8, count: 3)];
    await tester.pumpWidget(harness(child: const HomeScreen(), backend: b));
    await tester.pumpAndSettle();
    await tester.tap(find.text('성수 찐국밥'));
    await tester.pumpAndSettle();
    expect(find.text('detail:a'), findsOneWidget);
  });

  testWidgets('후기 쓰기 버튼은 /write 로 이동', (tester) async {
    await tester.pumpWidget(harness(child: const HomeScreen(), backend: FakeBackend()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('후기 쓰기'));
    await tester.pumpAndSettle();
    expect(find.text('write:'), findsOneWidget);
  });

  testWidgets('확정된 대마왕이 있으면 배너 표시, 누르면 그 유저 프로필', (tester) async {
    final b = FakeBackend()
      ..crown = const Crown(uid: 'seed1', likes: 16, status: 'confirmed')
      ..users = {'seed1': appUser('seed1')};
    await tester.pumpWidget(harness(child: const HomeScreen(), backend: b));
    await tester.pumpAndSettle();

    expect(find.textContaining('찐후기 대마왕'), findsOneWidget);
    expect(find.textContaining('닉-seed1'), findsOneWidget);
    await tester.tap(find.textContaining('찐후기 대마왕'));
    await tester.pumpAndSettle();
    expect(find.text('profile:seed1'), findsOneWidget);
  });

  testWidgets('대마왕이 없으면 배너 없음', (tester) async {
    await tester.pumpWidget(harness(child: const HomeScreen(), backend: FakeBackend()));
    await tester.pumpAndSettle();
    expect(find.textContaining('대마왕'), findsNothing);
  });

  testWidgets('정렬 칩이 두 개 있고 거품 큰 순을 선택할 수 있음', (tester) async {
    await tester.pumpWidget(harness(child: const HomeScreen(), backend: FakeBackend()));
    await tester.pumpAndSettle();
    expect(find.text('찐점수순'), findsOneWidget);
    await tester.tap(find.text('거품 큰 순'));
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '거품 큰 순'));
    expect(chip.selected, isTrue);
  });
}
