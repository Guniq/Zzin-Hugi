import 'package:flutter_test/flutter_test.dart';
import 'package:zzinhugi/core/regions.dart';
import 'package:zzinhugi/domain/errors.dart';

void main() {
  test('베타 지역은 화곡', () {
    expect(betaRegions, hasLength(1));
    expect(betaRegions.first.id, 'hwagok');
    expect(betaRegions.first.name, '화곡');
    // 화곡역 인근 (서버 DEFAULT_NEAR 와 같은 기준점)
    expect(betaRegions.first.lat, closeTo(37.5412, 1e-6));
    expect(betaRegions.first.lng, closeTo(126.8402, 1e-6));
  });

  test('지역 밖 오류 문구에 베타 지역 이름이 들어감', () {
    expect(reviewErrorText('out_of_region'), contains('화곡'));
    expect(reviewErrorText('out_of_region'), isNot(contains('성수')));
  });
}
