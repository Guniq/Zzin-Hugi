import 'package:flutter_test/flutter_test.dart';
import 'package:zzinhugi/domain/errors.dart';

void main() {
  test('알려진 코드는 한국어 문구', () {
    expect(reviewErrorText('store_mismatch'), contains('영수증'));
    expect(reviewErrorText('date_expired'), contains('30일'));
    expect(reviewErrorText('duplicate'), contains('이미'));
    expect(reviewErrorText('daily_limit'), contains('하루'));
    expect(reviewErrorText('out_of_region'), contains('베타'));
    expect(reviewErrorText('ocr_unavailable'), contains('다시'));
    expect(reviewErrorText('unreadable'), contains('읽'));
  });
  test('필드명(invalid-argument)은 입력 확인 문구', () {
    expect(reviewErrorText('text'), contains('입력'));
    expect(reviewErrorText('eventStars'), contains('입력'));
  });
  test('null/알 수 없는 값은 기본 문구', () {
    expect(reviewErrorText(null), '알 수 없는 오류가 발생했어요. 잠시 후 다시 시도해 주세요.');
  });
}
