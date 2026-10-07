import 'package:flutter_test/flutter_test.dart';
import 'package:zzinhugi/domain/score.dart';

void main() {
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
    expect(bubbleLevel(0.4), BubbleLevel.low);
    expect(bubbleLevel(0.5), BubbleLevel.mid);
    expect(bubbleLevel(1.4), BubbleLevel.mid);
    expect(bubbleLevel(1.5), BubbleLevel.high);
    expect(bubbleLevel(-3), BubbleLevel.low);
  });
}
