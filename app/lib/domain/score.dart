double round1(double x) => (x * 10).round() / 10;

String scoreText(double? v) => v == null ? '데이터 부족' : v.toStringAsFixed(1);

String bubbleText(double? v) => v == null ? '-' : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}';

enum BubbleLevel { unknown, low, mid, high }

BubbleLevel bubbleLevel(double? v) {
  if (v == null) return BubbleLevel.unknown;
  if (v < 0.5) return BubbleLevel.low;
  if (v < 1.5) return BubbleLevel.mid;
  return BubbleLevel.high;
}
