import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zzinhugi/ui/gauge.dart';

void main() {
  test('gaugeFraction: 0~10 점수를 0~1 로, 범위 밖은 자름', () {
    expect(gaugeFraction(0), 0);
    expect(gaugeFraction(2.3), closeTo(0.23, 1e-9));
    expect(gaugeFraction(10), 1);
    expect(gaugeFraction(12), 1);
    expect(gaugeFraction(-1), 0);
  });

  testWidgets('BubbleGauge: 찐점수만, 둘 다, 둘 다 없음 모두 그려짐', (tester) async {
    for (final g in const [
      BubbleGauge(real: 7.8),
      BubbleGauge(real: 2.3, event: 10),
      BubbleGauge(real: null),
    ]) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 300, child: g))));
      expect(tester.takeException(), isNull);
      expect(find.byType(BubbleGauge), findsOneWidget);
    }
  });
}
