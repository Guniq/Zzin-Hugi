import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zzinhugi/data/providers.dart';
import 'package:zzinhugi/domain/models.dart';
import 'package:zzinhugi/features/write/map/place_map.dart';
import 'package:zzinhugi/features/write/write_review_screen.dart';

import '../fake_map.dart';
import '../helpers.dart';

const p1 = PlaceResult(placeId: 'p1', name: '성수 찐국밥', address: '서울 성동구 성수동2가 300-1', category: '한식 · 국밥', region: 'seongsu');
const far = PlaceResult(placeId: 'far', name: '강남 찐돈까스', address: '서울 강남구 역삼동 100', category: '일식 · 돈까스', region: null);

Restaurant rest(String id, String name) => Restaurant(id: id, name: name, address: '서울', region: 'seongsu');

XFile fakeImage() => XFile.fromData(Uint8List.fromList([1, 2, 3]), mimeType: 'image/png', name: 'r.png');

FakeBackend backend() => FakeBackend()
  ..places = [p1, far]
  ..restaurants = [rest('a', '가게A'), rest('b', '가게B')]
  ..users = {'me': appUser('me')};

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

Future<void> chooseStars(WidgetTester t, int n) async {
  await t.tap(find.byKey(Key('real-$n')));
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
  testWidgets('전체 흐름: 실제 별점과 이벤트 별점을 함께 매기고 제출하면 계약대로 전달되고 상세로 이동', (tester) async {
    final b = backend();
    await tester.pumpWidget(screen(b));
    await tester.pumpAndSettle();

    await searchAndPick(tester, '성수 찐국밥');
    await next(tester);
    await pickReceipt(tester);
    await next(tester);

    await chooseStars(tester, 2);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('이벤트 때 준 별점'), findsOneWidget);
    await tester.tap(find.byKey(const Key('star-4')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('compare-preview')), findsOneWidget);
    expect(find.textContaining('이벤트 ★4 → 실제 ★2'), findsOneWidget);
    await next(tester);

    await tester.tap(find.text('사진 추가'));
    await tester.pumpAndSettle();
    await writeTextAndSubmit(tester);

    final s = b.lastSubmit!;
    expect(s.placeId, 'p1');
    expect(s.stars, 2);
    expect(s.eventJoined, isTrue);
    expect(s.eventStars, 4);
    expect(s.text, '국물이 진하고 고기가 많아요');
    expect(s.receiptPath, 'receipts/me/0.jpg');
    expect(s.photos, ['photos/me/1.jpg', 'photos/me/2.jpg']);
    expect(find.text('detail:p1'), findsOneWidget);
  });

  testWidgets('이벤트에 참여하지 않으면 이벤트 별점 없이 제출', (tester) async {
    final b = backend();
    await tester.pumpWidget(screen(b, initial: p1));
    await tester.pumpAndSettle();
    await pickReceipt(tester);
    await next(tester);
    await chooseStars(tester, 4);
    expect(find.text('이벤트 때 준 별점'), findsNothing);
    await next(tester);
    await writeTextAndSubmit(tester);
    expect(b.lastSubmit!.stars, 4);
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

  testWidgets('검색 결과에 업종과 주소가 보이고, 선택하면 체크 표시', (tester) async {
    await tester.pumpWidget(screen(backend()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '찐');
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();
    expect(find.text('한식 · 국밥'), findsOneWidget);
    expect(find.text('서울 성동구 성수동2가 300-1'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
    await tester.tap(find.text('성수 찐국밥'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('검색 결과가 없으면 안내 문구', (tester) async {
    final b = backend()..places = [];
    await tester.pumpWidget(screen(b));
    await tester.pumpAndSettle();
    expect(find.textContaining('검색 결과가 없어요'), findsNothing); // 검색 전에는 안내 없음
    await tester.enterText(find.byType(TextField), '없는집');
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();
    expect(find.text('검색 결과가 없어요'), findsOneWidget);
    expect(b.searched, ['없는집']);
  });

  testWidgets('검색 실패는 이유를 보여 주고 다시 검색 가능', (tester) async {
    final b = backend()..searchError = FirebaseFunctionsException(message: 'kakao_unavailable', code: 'unavailable');
    await tester.pumpWidget(screen(b));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '찐');
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();
    expect(find.textContaining('식당 검색이 잠시 안 돼요'), findsOneWidget);
    b.searchError = null;
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();
    expect(find.textContaining('식당 검색이 잠시 안 돼요'), findsNothing);
    expect(find.text('성수 찐국밥'), findsOneWidget);
  });

  testWidgets('빈 검색어는 검색하지 않음', (tester) async {
    final b = backend();
    await tester.pumpWidget(screen(b));
    await tester.pumpAndSettle();
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();
    expect(b.searched, isEmpty);
  });

  testWidgets('단계별 필수 입력: 영수증·별점·한줄평', (tester) async {
    await tester.pumpWidget(screen(backend(), initial: p1));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음')).onPressed, isNull);
    await pickReceipt(tester);
    await next(tester);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음')).onPressed, isNull);
    await chooseStars(tester, 1);
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
    await chooseStars(tester, 3);
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
    await chooseStars(tester, 3);
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

  group('지도 모드', () {
    Widget mapScreen(FakeBackend b, FakeMapControls c) => harness(
          child: const WriteReviewScreen(),
          backend: b,
          overrides: <Override>[
            mapEnabledProvider.overrideWithValue(true),
            placeMapBuilderProvider.overrideWithValue(fakeMapBuilder(c)),
            imagePickerProvider.overrideWithValue(() async => fakeImage()),
          ],
        );

    testWidgets('검색 → 이 식당 선택 → 영수증 단계로 이동', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final b = backend();
      await tester.pumpWidget(mapScreen(b, FakeMapControls()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '찐');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('이 식당 선택'));
      await tester.pumpAndSettle();
      expect(find.text('영수증 사진 선택'), findsOneWidget);
      await pickReceipt(tester);
      await tester.tap(find.text('이전'));
      await tester.pumpAndSettle();
      // 영수증 단계의 "이전"은 식당 찾기(지도)로 돌아간다
      expect(find.byTooltip('내 위치'), findsOneWidget);
    });

    testWidgets('목록 보기로 바꾸면 검색어·결과가 유지되고, 지도로 보기로 되돌아감', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final b = backend();
      await tester.pumpWidget(mapScreen(b, FakeMapControls()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '찐');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('목록 보기'));
      await tester.pumpAndSettle();
      expect(find.text('성수 찐국밥'), findsOneWidget);
      expect(find.text('베타 지역 아님'), findsOneWidget);
      await tester.tap(find.text('성수 찐국밥'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음')).onPressed, isNotNull);

      await tester.tap(find.text('지도로 보기'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('내 위치'), findsOneWidget);
    });

    testWidgets('지도를 쓸 수 없는 환경(기본값)은 목록 화면으로 시작하고 지도 버튼이 없음', (tester) async {
      await tester.pumpWidget(screen(backend()));
      await tester.pumpAndSettle();
      expect(find.byTooltip('내 위치'), findsNothing);
      expect(find.text('지도로 보기'), findsNothing);
      expect(find.text('검색'), findsOneWidget);
    });
  });

}
