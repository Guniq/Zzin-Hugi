import 'package:flutter_test/flutter_test.dart';
import 'package:zzinhugi/core/regions.dart';
import 'package:zzinhugi/domain/errors.dart';

void main() {
  test('베타 지역은 화곡', () {
    expect(betaRegions, hasLength(1));
    expect(betaRegions.first.id, 'hwagok');
    expect(betaRegions.first.name, '화곡');
  });

  test('지역 밖 오류 문구에 베타 지역 이름이 들어감', () {
    expect(reviewErrorText('out_of_region'), contains('화곡'));
    expect(reviewErrorText('out_of_region'), isNot(contains('성수')));
  });
}
