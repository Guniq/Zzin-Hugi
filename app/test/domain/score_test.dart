import 'package:flutter_test/flutter_test.dart';
import 'package:zzinhugi/domain/score.dart';

void main() {
  group('personalScore (백엔드와 같은 값)', () {
    test('혼자면 구간 중앙', () {
      expect(personalScore(Tier.best, 0, 1), 8.5);
      expect(personalScore(Tier.ok, 0, 1), 5.5);
      expect(personalScore(Tier.bad, 0, 1), 2.0);
    });
    test('둘이면 위아래로 나뉨', () {
      expect(personalScore(Tier.best, 0, 2), 9.3);
      expect(personalScore(Tier.best, 1, 2), 7.8);
    });
  });

  test('scoreText: null은 데이터 부족', () {
    expect(scoreText(null), '데이터 부족');
    expect(scoreText(7.8), '7.8');
    expect(scoreText(8), '8.0');
  });

  test('bubbleText', () {
    expect(bubbleText(null), '-');
    expect(bubbleText(7.7), '+7.7');
    expect(bubbleText(0), '+0.0');
    expect(bubbleText(-1.2), '-1.2');
  });

  test('bubbleLevel 경계', () {
    expect(bubbleLevel(null), BubbleLevel.unknown);
    expect(bubbleLevel(0.9), BubbleLevel.low);
    expect(bubbleLevel(1.0), BubbleLevel.mid);
    expect(bubbleLevel(2.4), BubbleLevel.mid);
    expect(bubbleLevel(2.5), BubbleLevel.high);
    expect(bubbleLevel(-3), BubbleLevel.low);
  });

  test('Tier 라벨', () {
    expect(Tier.values.map((t) => t.label), ['최고', '괜찮', '별로']);
  });
}
