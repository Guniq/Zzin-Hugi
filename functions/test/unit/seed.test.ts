import { buildSeedData } from '../../src/dev/seed';

const NOW = new Date('2026-10-07T03:00:00Z');
const d = buildSeedData(NOW);

test('찐점수·거품지수 계산 결과', () => {
  expect(d.restaurants['fake-1']).toMatchObject({ reviewCount: 3, realScore: 7.8, eventScore: null, bubble: null });
  expect(d.restaurants['fake-3']).toMatchObject({ reviewCount: 3, realScore: 7.5 });
  expect(d.restaurants['fake-2']).toMatchObject({ realScore: 3.8, eventScore: 10, bubble: 6.2 });
  expect(d.restaurants['fake-4']).toMatchObject({ realScore: 2.3, eventScore: 10, bubble: 7.7 });
});

test('후기 없는 식당은 점수 필드가 없음 (홈 목록에서 제외됨)', () => {
  expect(d.restaurants['fake-5']).not.toHaveProperty('realScore');
  expect(d.restaurants['fake-5']).toMatchObject({ region: 'seongsu' });
  expect(d.restaurants['fake-6']).toMatchObject({ region: null });
});

test('후기·유저·대마왕', () => {
  expect(Object.keys(d.reviews)).toHaveLength(12);
  expect(d.reviews['seed1_fake-1']).toMatchObject({ tier: 'best', personalScore: 9.3, likeCount: 4, eventJoined: false });
  expect(d.reviews['seed1_fake-4']).toMatchObject({ tier: 'bad', eventJoined: true, eventStars: 5 });
  expect(d.users['seed1']).toMatchObject({ nickname: '찐미식가', verifiedReviewCount: 4, likesReceived: 16, title: '찐후기러' });
  expect(d.users['seed3']).toMatchObject({ likesReceived: 4, title: '찐린이' });
  expect(d.crown).toMatchObject({ id: '2026-10_seongsu', data: { uid: 'seed1', status: 'confirmed', region: 'seongsu' } });
});
