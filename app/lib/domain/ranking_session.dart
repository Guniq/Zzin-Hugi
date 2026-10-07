/// 새 식당을 같은 등급의 기존 식당 목록(좋은 순)에 끼워 넣을 위치를 이진 탐색으로 찾는다.
class RankingSession {
  RankingSession(this.candidates) : _hi = candidates.length;

  final List<String> candidates;
  int _lo = 0;
  int _hi;

  bool get done => _lo >= _hi;
  String? get current => done ? null : candidates[(_lo + _hi) ~/ 2];

  /// [done]일 때 삽입 위치(0 = 맨 위).
  int get index => _lo;

  void answer({required bool newIsBetter}) {
    final mid = (_lo + _hi) ~/ 2;
    if (newIsBetter) {
      _hi = mid;
    } else {
      _lo = mid + 1;
    }
  }
}
