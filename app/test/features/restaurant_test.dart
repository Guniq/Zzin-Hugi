import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zzinhugi/domain/models.dart';
import 'package:zzinhugi/domain/score.dart';
import 'package:zzinhugi/features/restaurant/restaurant_screen.dart';

import '../helpers.dart';

const place = Restaurant(
  id: 'p1', name: '성수 찐고기', address: '서울 성동구 성수동2가 31', region: 'seongsu',
  realScore: 2.3, eventScore: 10, bubble: 7.7, reviewCount: 3, eventReviewCount: 3,
);

Review review(String id, String uid, {Tier tier = Tier.bad, bool event = true, int likes = 2, String text = '이벤트 때문에 갔는데 별로였어요'}) =>
    Review(
      id: id, uid: uid, restaurantId: 'p1', tier: tier, personalScore: 2.0, eventJoined: event,
      eventStars: event ? 5 : null, text: text, photos: const [], visitDate: '2026-10-06', likeCount: likes,
    );

FakeBackend backendWith(List<Review> reviews) => FakeBackend()
  ..restaurants = [place]
  ..reviews = reviews
  ..users = {'other': appUser('other'), 'me': appUser('me')};

void tall(WidgetTester t) {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('점수 요약과 후기 내용', (tester) async {
    tall(tester);
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: backendWith([review('other_p1', 'other')])));
    await tester.pumpAndSettle();

    expect(find.text('성수 찐고기'), findsWidgets);
    expect(find.text('2.3'), findsOneWidget);
    expect(find.text('이벤트 점수'), findsOneWidget);
    expect(find.text('10.0'), findsOneWidget);
    expect(find.text('거품 +7.7'), findsOneWidget);
    expect(find.text('닉-other'), findsOneWidget);
    expect(find.text('별로'), findsOneWidget);
    expect(find.text('2.0'), findsOneWidget);
    expect(find.textContaining('이벤트 참여'), findsOneWidget);
    expect(find.text('이벤트 때문에 갔는데 별로였어요'), findsOneWidget);
  });

  testWidgets('이벤트 미참여 후기에는 이벤트 라벨 없음', (tester) async {
    tall(tester);
    await tester.pumpWidget(harness(
        child: const RestaurantScreen(id: 'p1'), backend: backendWith([review('other_p1', 'other', event: false)])));
    await tester.pumpAndSettle();
    expect(find.textContaining('이벤트 참여'), findsNothing);
  });

  testWidgets('따봉 누르면 setLike(true), 이미 눌렀으면 setLike(false)', (tester) async {
    tall(tester);
    final b = backendWith([review('other_p1', 'other')]);
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: b));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.thumb_up_outlined));
    await tester.pumpAndSettle();
    expect(b.likeCalls, [('other_p1', true)]);

    final b2 = backendWith([review('other_p1', 'other')])..liked = {'other_p1': true};
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: b2));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.thumb_up));
    await tester.pumpAndSettle();
    expect(b2.likeCalls, [('other_p1', false)]);
  });

  testWidgets('본인 후기 따봉 비활성', (tester) async {
    tall(tester);
    final b = backendWith([review('me_p1', 'me')]);
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: b));
    await tester.pumpAndSettle();
    final btn = tester.widget<TextButton>(find.widgetWithIcon(TextButton, Icons.thumb_up_outlined));
    expect(btn.onPressed, isNull);
  });

  testWidgets('인증 후기 없으면 따봉 안내 (쓰기 호출 안 함)', (tester) async {
    tall(tester);
    final b = backendWith([review('other_p1', 'other')])..users = {'other': appUser('other'), 'me': appUser('me', verified: 0)};
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: b));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.thumb_up_outlined));
    await tester.pumpAndSettle();
    expect(find.text('영수증 인증 후기를 1개 이상 쓰면 따봉을 줄 수 있어요'), findsOneWidget);
    expect(b.likeCalls, isEmpty);
  });

  testWidgets('신고: 사유 입력 후 접수', (tester) async {
    tall(tester);
    final b = backendWith([review('other_p1', 'other')]);
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: b));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '광고 같아요');
    await tester.tap(find.text('신고하기'));
    await tester.pumpAndSettle();
    expect(b.reports, [('other_p1', '광고 같아요')]);
    expect(find.text('신고가 접수됐어요'), findsOneWidget);
  });

  testWidgets('후기가 없으면 안내', (tester) async {
    tall(tester);
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: backendWith([])));
    await tester.pumpAndSettle();
    expect(find.text('아직 후기가 없어요'), findsOneWidget);
  });

  testWidgets('이 식당 후기 쓰기 → /write 로 식당 전달', (tester) async {
    tall(tester);
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: backendWith([])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 식당 후기 쓰기'));
    await tester.pumpAndSettle();
    expect(find.text('write:p1'), findsOneWidget);
  });

  testWidgets('작성자 이름을 누르면 프로필', (tester) async {
    tall(tester);
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: backendWith([review('other_p1', 'other')])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('닉-other'));
    await tester.pumpAndSettle();
    expect(find.text('profile:other'), findsOneWidget);
  });
}
