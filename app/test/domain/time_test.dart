import 'package:flutter_test/flutter_test.dart';
import 'package:zzinhugi/core/time.dart';

void main() {
  test('UTC 9/30 15:00 은 KST 10월', () {
    expect(kstMonth(DateTime.utc(2026, 9, 30, 15)), '2026-10');
  });
  test('UTC 10/31 14:59 은 아직 10월', () {
    expect(kstMonth(DateTime.utc(2026, 10, 31, 14, 59)), '2026-10');
  });
}
