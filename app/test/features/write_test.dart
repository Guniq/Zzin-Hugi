import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jjinhugi/data/providers.dart';
import 'package:jjinhugi/domain/models.dart';
import 'package:jjinhugi/domain/score.dart';
import 'package:jjinhugi/features/write/write_review_screen.dart';

import '../helpers.dart';

const p1 = PlaceResult(placeId: 'p1', name: '성수 찐국밥', address: '서울 성동구 성수동2가 300-1', region: 'seongsu');
const far = PlaceResult(placeId: 'far', name: '강남 찐돈까스', address: '서울 강남구 역삼동 100', region: null);

Restaurant rest(String id, String name) => Restaurant(id: id, name: name, address: '서울', region: 'seongsu');

XFile fakeImage() => XFile.fromData(Uint8List.fromList([1, 2, 3]), mimeType: 'image/png', name: 'r.png');

FakeBackend backend({Map<String, List<String>> ranking = const {}}) => FakeBackend()
  ..places = [p1, far]
  ..restaurants = [rest('a', '가게A'), rest('b', '가게B')]
  ..users = {'me': appUser('me', ranking: ranking)};

Widget screen(FakeBackend b, {PlaceResult? initial}) => harness(
      child: WriteReviewScreen(initialPlace: initial),
      backend: b,
      overrides: <Override>[
        imagePickerProvider.overrideWithValue(() async => fakeImage()),
        photosPickerProvider.overrideWithValue(() async => [fakeImage(), fakeImage()]),
      ],
    );

Future<void> next(WidgetTester t) async {
  await t.tap(find.text('다음'));
  await t.pumpAndSettle();
}

Future<void> pickReceipt(WidgetTester t) async {
  await t.tap(find.text('영수증 사진 선택'));
  await t.pumpAndSettle();
  expect(find.text('영수증 선택됨'), findsOneWidget);
}

Future<void> chooseTier(WidgetTester t, Tier tier) async {
  await t.tap(find.widgetWithText(ChoiceChip, tier.label));
  await t.pumpAndSettle();
}

Future<void> searchAndPick(WidgetTester t, String name) async {
  await t.enterText(find.byType(TextField), '찐');
  await t.tap(find.text('검색'));
  await t.pumpAndSettle();
  await t.tap(find.text(name));
  await t.pumpAndSettle();
}

Future<void> writeTextAndSubmit(WidgetTester t, [String text = '국물이 진하고 고기가 많아요']) async {
  await t.enterText(find.byType(TextField), text);
  await t.pumpAndSettle();
  await t.tap(find.text('제출'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('전체 흐름: 비교 후 제출하면 입력값이 계약대로 전달되고 상세로 이동', (tester) async {
    final b = backend(ranking: {'best': ['a', 'b']});
    await tester.pumpWidget(screen(b));
    await tester.pumpAndSettle();

    await searchAndPick(tester, '성수 찐국밥');
    await next(tester);
    await pickReceipt(tester);
    await next(tester);
    await chooseTier(tester, Tier.best);
    await next(tester);

    // 후보 [a, b] — 첫 질문은 가운데(b), 새 식당이 더 좋다고 두 번 답하면 맨 위
    expect(find.textContaining('가게B'), findsOneWidget);
    await tester.tap(find.text('이번 식당이 더 좋았어요'));
    await tester.pumpAndSettle();
    expect(find.textContaining('가게A'), findsOneWidget);
    await tester.tap(find.text('이번 식당이 더 좋았어요'));
    await tester.pumpAndSettle();
    expect(find.textContaining('순위가 정해졌어요'), findsOneWidget);
    await next(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('이벤트 때 준 별점'), findsOneWidget);
    await tester.tap(find.byKey(const Key('star-4')));
    await tester.pumpAndSettle();
    await next(tester);

    await tester.tap(find.text('사진 추가'));
    await tester.pumpAndSettle();
    await writeTextAndSubmit(tester);

    final s = b.lastSubmit!;
    expect(s.placeId, 'p1');
    expect(s.tier, Tier.best);
    expect(s.rankIndex, 0);
    expect(s.eventJoined, isTrue);
    expect(s.eventStars, 4);
    expect(s.text, '국물이 진하고 고기가 많아요');
    expect(s.receiptPath, 'receipts/me/0.jpg');
    expect(s.photos, ['photos/me/1.jpg', 'photos/me/2.jpg']);
    expect(find.text('detail:p1'), findsOneWidget);
  });

  testWidgets('후보에서 현재 식당 제외 (같은 식당 재방문)', (tester) async {
    final b = backend(ranking: {'best': ['p1', 'b']});
    b.restaurants = [rest('p1', '성수 찐국밥'), rest('b', '가게B')];
    await tester.pumpWidget(screen(b, initial: p1));
    await tester.pumpAndSettle();

    await pickReceipt(tester);
    await next(tester);
    await chooseTier(tester, Tier.best);
    await next(tester);

    // 후보는 [b] 하나뿐이어야 한다. 자기 자신('성수 찐국밥')과 비교하면 안 됨
    expect(find.textContaining('가게B'), findsOneWidget);
    expect(find.textContaining('비교 식당이 더 좋았어요'), findsOneWidget);
    await tester.tap(find.text('비교 식당이 더 좋았어요'));
    await tester.pumpAndSettle();
    expect(find.textContaining('순위가 정해졌어요'), findsOneWidget);
    await next(tester);
    await next(tester);
    await writeTextAndSubmit(tester);
    expect(b.lastSubmit!.rankIndex, 1);
  });

  testWidgets('같은 등급 식당이 없으면 비교 없이 위치 0', (tester) async {
    final b = backend();
    await tester.pumpWidget(screen(b, initial: p1));
    await tester.pumpAndSettle();
    await pickReceipt(tester);
    await next(tester);
    await chooseTier(tester, Tier.ok);
    await next(tester);
    expect(find.text('같은 등급에 비교할 식당이 아직 없어요'), findsOneWidget);
    await next(tester);
    await next(tester);
    await writeTextAndSubmit(tester);
    expect(b.lastSubmit!.rankIndex, 0);
    expect(b.lastSubmit!.eventJoined, isFalse);
    expect(b.lastSubmit!.eventStars, isNull);
  });

  testWidgets('베타 지역 밖 식당 선택 불가', (tester) async {
    await tester.pumpWidget(screen(backend()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '찐');
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();
    expect(find.text('베타 지역 아님'), findsOneWidget);
    await tester.tap(find.text('강남 찐돈까스'));
    await tester.pumpAndSettle();
    final nextBtn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음'));
    expect(nextBtn.onPressed, isNull);
  });

  testWidgets('단계별 필수 입력: 영수증·등급·한줄평', (tester) async {
    await tester.pumpWidget(screen(backend(), initial: p1));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음')).onPressed, isNull);
    await pickReceipt(tester);
    await next(tester);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음')).onPressed, isNull);
    await chooseTier(tester, Tier.bad);
    await next(tester);
    await next(tester);
    await next(tester);
    await tester.enterText(find.byType(TextField), '짧아요');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '제출')).onPressed, isNull);
  });

  testWidgets('제출 실패 시 입력 보존 + 이유 표시, 다시 제출 가능', (tester) async {
    final b = backend()
      ..submitError = FirebaseFunctionsException(message: 'store_mismatch', code: 'failed-precondition');
    await tester.pumpWidget(screen(b, initial: p1));
    await tester.pumpAndSettle();
    await pickReceipt(tester);
    await next(tester);
    await chooseTier(tester, Tier.ok);
    await next(tester);
    await next(tester);
    await next(tester);
    await writeTextAndSubmit(tester, '무난하게 먹기 좋았어요 괜찮음');

    expect(find.textContaining('영수증의 가게가 선택한 식당과 달라요'), findsOneWidget);
    expect(find.text('무난하게 먹기 좋았어요 괜찮음'), findsOneWidget); // 입력 유지
    expect(find.text('detail:p1'), findsNothing);

    b.submitError = null;
    await tester.tap(find.text('제출'));
    await tester.pumpAndSettle();
    expect(b.lastSubmit!.text, '무난하게 먹기 좋았어요 괜찮음');
    expect(find.text('detail:p1'), findsOneWidget);
  });

  testWidgets('알 수 없는 예외도 기본 문구로 표시', (tester) async {
    final b = backend()..submitError = StateError('boom');
    await tester.pumpWidget(screen(b, initial: p1));
    await tester.pumpAndSettle();
    await pickReceipt(tester);
    await next(tester);
    await chooseTier(tester, Tier.ok);
    await next(tester);
    await next(tester);
    await next(tester);
    await writeTextAndSubmit(tester);
    expect(find.textContaining('알 수 없는 오류'), findsOneWidget);
  });

  testWidgets('이전 버튼으로 돌아가면 선택값 유지', (tester) async {
    await tester.pumpWidget(screen(backend(), initial: p1));
    await tester.pumpAndSettle();
    await pickReceipt(tester);
    await next(tester);
    await tester.tap(find.text('이전'));
    await tester.pumpAndSettle();
    expect(find.text('영수증 선택됨'), findsOneWidget);
  });
}
