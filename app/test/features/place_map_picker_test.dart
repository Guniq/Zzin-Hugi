import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zzinhugi/core/regions.dart';
import 'package:zzinhugi/domain/models.dart';
import 'package:zzinhugi/features/write/map/place_map_picker.dart';

import '../fake_map.dart';
import '../helpers.dart';

const hg1 = PlaceResult(placeId: 'hg1', name: '화곡 찐국밥', address: '서울 강서구 화곡동 1011-3', category: '한식 · 국밥', region: 'hwagok', lat: 37.5415, lng: 126.8405);
const hg2 = PlaceResult(placeId: 'hg2', name: '화곡 찐카페', address: '서울 강서구 화곡동 1012-7', category: '카페', region: 'hwagok', lat: 37.5420, lng: 126.8410);
const far = PlaceResult(placeId: 'far', name: '강남 찐돈까스', address: '서울 강남구 역삼동 100', category: '일식 · 돈까스', region: null, lat: 37.5000, lng: 127.0360);

class Probe {
  PlaceResult? picked;
  int closed = 0;
  String? listQuery;
  List<PlaceResult>? listResults;
}

Widget picker(FakeBackend b, FakeMapControls c, Probe p) => harness(
      child: PlaceMapPicker(
        onPicked: (x) => p.picked = x,
        onClose: () => p.closed++,
        onShowList: (q, r) {
          p.listQuery = q;
          p.listResults = r;
        },
      ),
      backend: b,
      overrides: <Override>[placeMapBuilderProvider.overrideWithValue(fakeMapBuilder(c))],
    );

Future<void> search(WidgetTester t, String q) async {
  await t.enterText(find.byType(TextField), q);
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pumpAndSettle();
}

FakeBackend backend({List<PlaceResult> places = const [hg1, hg2, far]}) => FakeBackend()..places = places;

void tall(WidgetTester t) {
  t.view.physicalSize = const Size(800, 1600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('검색하면 지도 중심 좌표로 서버를 부르고 핀을 찍고 가장 가까운 가게를 선택', (tester) async {
    tall(tester);
    final b = backend();
    final c = FakeMapControls();
    await tester.pumpWidget(picker(b, c, Probe()));
    await tester.pumpAndSettle();
    await search(tester, '국밥');

    expect(b.searchCalls, [('국밥', betaRegions.first.lat, betaRegions.first.lng)]);
    final call = c.markerCalls.last;
    expect(call.markers.map((m) => m.id), ['hg1', 'hg2', 'far']);
    expect(call.markers.map((m) => m.blocked), [false, false, true]);
    expect(call.selectedId, 'hg1');
    expect(call.fit, isTrue);
    expect(find.text('화곡 찐국밥'), findsOneWidget);
    expect(find.text('한식 · 국밥'), findsOneWidget);
    expect(find.text('서울 강서구 화곡동 1011-3'), findsOneWidget);
  });

  testWidgets('핀을 누르면 선택이 바뀌고 카드가 갱신', (tester) async {
    tall(tester);
    final c = FakeMapControls();
    await tester.pumpWidget(picker(backend(), c, Probe()));
    await tester.pumpAndSettle();
    await search(tester, '찐');
    c.tapMarker!('hg2');
    await tester.pumpAndSettle();
    expect(find.text('화곡 찐카페'), findsOneWidget);
    expect(find.text('화곡 찐국밥'), findsNothing);
    expect(c.markerCalls.last.selectedId, 'hg2');
    expect(c.markerCalls.last.fit, isFalse);
  });

  testWidgets('이 식당 선택 → onPicked', (tester) async {
    tall(tester);
    final p = Probe();
    await tester.pumpWidget(picker(backend(), FakeMapControls(), p));
    await tester.pumpAndSettle();
    await search(tester, '찐');
    await tester.tap(find.text('이 식당 선택'));
    await tester.pumpAndSettle();
    expect(p.picked?.placeId, 'hg1');
  });

  testWidgets('베타 지역 밖 가게는 선택 불가', (tester) async {
    tall(tester);
    final p = Probe();
    final c = FakeMapControls();
    await tester.pumpWidget(picker(backend(), c, p));
    await tester.pumpAndSettle();
    await search(tester, '찐');
    c.tapMarker!('far');
    await tester.pumpAndSettle();
    final btn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '베타 지역 아님'));
    expect(btn.onPressed, isNull);
    expect(p.picked, isNull);
  });

  testWidgets('베타 지역 밖 결과만 있으면 선택은 첫 결과, 버튼은 비활성', (tester) async {
    tall(tester);
    final c = FakeMapControls();
    await tester.pumpWidget(picker(backend(places: const [far]), c, Probe()));
    await tester.pumpAndSettle();
    await search(tester, '돈까스');
    expect(c.markerCalls.last.selectedId, 'far');
    expect(find.widgetWithText(FilledButton, '베타 지역 아님'), findsOneWidget);
  });

  testWidgets('검색 후 지도를 움직이면 재검색 버튼, 누르면 새 중심으로 다시 검색', (tester) async {
    tall(tester);
    final b = backend();
    final c = FakeMapControls();
    await tester.pumpWidget(picker(b, c, Probe()));
    await tester.pumpAndSettle();
    await search(tester, '국밥');
    expect(find.text('이 지역에서 다시 검색'), findsNothing);

    c.userMoved!(37.55, 126.85);
    await tester.pumpAndSettle();
    expect(find.text('이 지역에서 다시 검색'), findsOneWidget);
    await tester.tap(find.text('이 지역에서 다시 검색'));
    await tester.pumpAndSettle();
    expect(b.searchCalls.last, ('국밥', 37.55, 126.85));
    expect(c.markerCalls.last.fit, isFalse); // 사용자가 보던 화면을 그대로 둔다
    expect(find.text('이 지역에서 다시 검색'), findsNothing);
  });

  testWidgets('검색어가 없으면 지도를 움직여도 재검색 버튼이 없음', (tester) async {
    tall(tester);
    final c = FakeMapControls();
    await tester.pumpWidget(picker(backend(), c, Probe()));
    await tester.pumpAndSettle();
    c.userMoved!(37.55, 126.85);
    await tester.pumpAndSettle();
    expect(find.text('이 지역에서 다시 검색'), findsNothing);
  });

  testWidgets('지도를 먼저 옮긴 뒤 검색하면 그 중심이 기준점', (tester) async {
    tall(tester);
    final b = backend();
    final c = FakeMapControls();
    await tester.pumpWidget(picker(b, c, Probe()));
    await tester.pumpAndSettle();
    c.userMoved!(37.56, 126.86);
    await tester.pumpAndSettle();
    await search(tester, '카페');
    expect(b.searchCalls.last, ('카페', 37.56, 126.86));
  });

  testWidgets('결과가 없으면 안내 문구, 선택 카드 없음', (tester) async {
    tall(tester);
    await tester.pumpWidget(picker(backend(places: const []), FakeMapControls(), Probe()));
    await tester.pumpAndSettle();
    await search(tester, '없는집');
    expect(find.text('검색 결과가 없어요'), findsOneWidget);
    expect(find.text('이 식당 선택'), findsNothing);
  });

  testWidgets('검색 실패는 이유를 보여 줌', (tester) async {
    tall(tester);
    final b = backend()..searchError = FirebaseFunctionsException(message: 'kakao_unavailable', code: 'unavailable');
    await tester.pumpWidget(picker(b, FakeMapControls(), Probe()));
    await tester.pumpAndSettle();
    await search(tester, '찐');
    expect(find.textContaining('식당 검색이 잠시 안 돼요'), findsOneWidget);
  });

  testWidgets('이미 후기가 있는 가게는 찐점수와 후기 수를 함께 보여 줌', (tester) async {
    tall(tester);
    final b = backend()
      ..restaurants = [
        const Restaurant(id: 'hg1', name: '화곡 찐국밥', address: '서울 강서구 화곡동 1011-3', region: 'hwagok', realScore: 7.8, reviewCount: 3),
      ];
    await tester.pumpWidget(picker(b, FakeMapControls(), Probe()));
    await tester.pumpAndSettle();
    await search(tester, '찐');
    expect(find.text('7.8'), findsOneWidget);
    expect(find.textContaining('인증 후기 3개'), findsOneWidget);
  });

  testWidgets('후기가 없는 가게에는 점수 줄이 없음', (tester) async {
    tall(tester);
    await tester.pumpWidget(picker(backend(), FakeMapControls(), Probe()));
    await tester.pumpAndSettle();
    await search(tester, '찐');
    expect(find.textContaining('인증 후기'), findsNothing);
  });

  testWidgets('목록 보기 → 현재 검색어와 결과를 넘김', (tester) async {
    tall(tester);
    final p = Probe();
    await tester.pumpWidget(picker(backend(), FakeMapControls(), p));
    await tester.pumpAndSettle();
    await search(tester, '찐');
    await tester.tap(find.text('목록 보기'));
    await tester.pumpAndSettle();
    expect(p.listQuery, '찐');
    expect(p.listResults?.map((x) => x.placeId), ['hg1', 'hg2', 'far']);
  });

  testWidgets('지도를 못 불러오면 안내와 목록 검색 버튼', (tester) async {
    tall(tester);
    final p = Probe();
    final c = FakeMapControls();
    await tester.pumpWidget(picker(backend(), c, p));
    await tester.pumpAndSettle();
    c.error!('sdk_load_failed');
    await tester.pumpAndSettle();
    expect(find.text('지도를 불러오지 못했어요'), findsOneWidget);
    await tester.tap(find.text('목록으로 검색'));
    await tester.pumpAndSettle();
    expect(p.listQuery, '');
    expect(p.listResults, isEmpty);
  });

  testWidgets('닫기 버튼', (tester) async {
    tall(tester);
    final p = Probe();
    await tester.pumpWidget(picker(backend(), FakeMapControls(), p));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(p.closed, 1);
  });

  testWidgets('내 위치: 실패하면 안내, 성공하면 지도를 옮김', (tester) async {
    tall(tester);
    final c = FakeMapControls();
    await tester.pumpWidget(picker(backend(), c, Probe()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('내 위치'));
    await tester.pumpAndSettle();
    expect(find.textContaining('내 위치를 가져오지 못했어요'), findsOneWidget);
    expect(c.moves, isEmpty);

    c.locateResult = const MapLatLng(37.55, 126.85);
    await tester.pump(const Duration(seconds: 5)); // 스낵바 시간 종료
    await tester.pumpAndSettle(); // 닫힘 애니메이션까지 끝나야 버튼이 가려지지 않는다
    await tester.tap(find.byTooltip('내 위치'));
    await tester.pumpAndSettle();
    expect(c.moves, [(37.55, 126.85)]);
  });
}
