import 'package:flutter_test/flutter_test.dart';
import 'package:jjinhugi/domain/ranking_session.dart';

void main() {
  test('후보가 없으면 바로 끝, 위치 0', () {
    final s = RankingSession([]);
    expect(s.done, isTrue);
    expect(s.current, isNull);
    expect(s.index, 0);
  });

  test('항상 새 식당이 더 좋으면 맨 위', () {
    final s = RankingSession(['a', 'b', 'c']);
    final asked = <String>[];
    while (!s.done) {
      asked.add(s.current!);
      s.answer(newIsBetter: true);
    }
    expect(s.index, 0);
    expect(asked, ['b', 'a']);
  });

  test('항상 비교 식당이 더 좋으면 맨 아래', () {
    final s = RankingSession(['a', 'b', 'c']);
    while (!s.done) {
      s.answer(newIsBetter: false);
    }
    expect(s.index, 3);
  });

  test('중간 삽입', () {
    final s = RankingSession(['a', 'b', 'c', 'd']);
    // mid=2(c): 새 식당이 더 좋음 → hi=2, mid=1(b): 비교가 더 좋음 → lo=2
    expect(s.current, 'c');
    s.answer(newIsBetter: true);
    expect(s.current, 'b');
    s.answer(newIsBetter: false);
    expect(s.done, isTrue);
    expect(s.index, 2);
  });

  test('질문 횟수는 최대 ceil(log2(n+1))', () {
    for (var n = 1; n <= 16; n++) {
      for (final better in [true, false]) {
        final s = RankingSession(List.generate(n, (i) => '$i'));
        var asked = 0;
        while (!s.done) {
          asked++;
          s.answer(newIsBetter: better);
        }
        var bound = 0;
        while ((1 << bound) < n + 1) {
          bound++;
        }
        expect(asked <= bound, isTrue, reason: 'n=$n better=$better asked=$asked bound=$bound');
      }
    }
  });
}
