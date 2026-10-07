enum Tier { best, ok, bad }

extension TierX on Tier {
  String get label => switch (this) { Tier.best => '최고', Tier.ok => '괜찮', Tier.bad => '별로' };
}

double round1(double x) => (x * 10).round() / 10;

/// 백엔드 functions/src/scoring.ts 의 personalScore 와 같은 공식.
double personalScore(Tier tier, int index, int n) {
  final (lo, hi) = switch (tier) {
    Tier.best => (7.0, 10.0),
    Tier.ok => (4.0, 7.0),
    Tier.bad => (0.0, 4.0),
  };
  return round1(hi - ((hi - lo) * (index + 0.5)) / n);
}

String scoreText(double? v) => v == null ? '데이터 부족' : v.toStringAsFixed(1);

String bubbleText(double? v) => v == null ? '-' : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}';

enum BubbleLevel { unknown, low, mid, high }

BubbleLevel bubbleLevel(double? v) {
  if (v == null) return BubbleLevel.unknown;
  if (v < 1) return BubbleLevel.low;
  if (v < 2.5) return BubbleLevel.mid;
  return BubbleLevel.high;
}
