import 'package:flutter_test/flutter_test.dart';
import 'package:zzinhugi/domain/models.dart';
import 'package:zzinhugi/domain/score.dart';

void main() {
  test('Restaurant: 점수 null과 정수 숫자 처리', () {
    final r = Restaurant.fromMap('p1', {
      'name': '찐국밥', 'address': '서울 성동구 성수동2가 1', 'region': 'seongsu',
      'realScore': 8, 'eventScore': null, 'bubble': null, 'reviewCount': 3, 'eventReviewCount': 0,
    });
    expect(r.realScore, 8.0);
    expect(r.eventScore, isNull);
    expect(r.toPlace().placeId, 'p1');
    expect(r.toPlace().region, 'seongsu');
  });

  test('Restaurant: 후기 없는 식당은 필드가 없어도 파싱', () {
    final r = Restaurant.fromMap('p2', {'name': 'x', 'address': 'y', 'region': null});
    expect(r.realScore, isNull);
    expect(r.reviewCount, 0);
    expect(r.region, isNull);
  });

  test('Review 파싱', () {
    final v = Review.fromMap('u1_p1', {
      'uid': 'u1', 'restaurantId': 'p1', 'stars': 2, 'eventJoined': true,
      'eventStars': 5, 'text': '별로였어요 이벤트로 갔음', 'photos': ['photos/u1/a.jpg'],
      'visitDate': '2026-10-06', 'likeCount': 3,
    });
    expect(v.stars, 2);
    expect(v.eventStars, 5);
    expect(v.photos, ['photos/u1/a.jpg']);
    expect(v.createdAt, isNull);
  });

  test('SubmitInput.toMap는 콜러블 계약 그대로', () {
    const i = SubmitInput(
      placeId: 'p1', receiptPath: 'receipts/u1/x.jpg', stars: 3,
      eventJoined: true, eventStars: 4, text: '무난했어요 괜찮아요 ㅎㅎ', photos: ['photos/u1/a.jpg'],
    );
    expect(i.toMap(), {
      'placeId': 'p1', 'receiptPath': 'receipts/u1/x.jpg', 'stars': 3,
      'eventJoined': true, 'eventStars': 4, 'text': '무난했어요 괜찮아요 ㅎㅎ', 'photos': ['photos/u1/a.jpg'],
    });
  });

  test('PlaceResult 파싱', () {
    final p = PlaceResult.fromMap({'placeId': 'k1', 'name': '찐', 'address': '서울', 'region': null, 'lat': 37.5, 'category': '한식 · 국밥'});
    expect(p.region, isNull);
    expect(p.name, '찐');
    expect(p.category, '한식 · 국밥');
    expect(p.lat, 37.5);
    expect(p.lng, isNull);
    expect(PlaceResult.fromMap({'placeId': 'k2', 'name': 'x'}).category, '');
  });

  test('Crown 파싱', () {
    final c = Crown.fromMap({'uid': 'seed1', 'likes': 16, 'status': 'confirmed'});
    expect(c.uid, 'seed1');
    expect(c.isConfirmed, isTrue);
  });
}
