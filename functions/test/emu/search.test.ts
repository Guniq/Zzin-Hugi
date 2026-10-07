import { testDb, clearFirestore } from './helpers';
import { searchPlacesCore, DEFAULT_NEAR } from '../../src/search';
import { KakaoPlace } from '../../src/kakao';

const db = testDb();
const NOW = new Date('2026-10-07T03:00:00Z');
const places: KakaoPlace[] = [
  { placeId: '111', name: '성수 찐국밥', address: '서울 성동구 성수동2가 300-1', roadAddress: '서울 성동구 연무장길 10', category: '한식 · 국밥', lat: 37.54, lng: 127.05 },
  { placeId: '999', name: '강남 찐면', address: '서울 강남구 역삼동 1', roadAddress: '', category: '일식 · 면요리', lat: 37.5, lng: 127.03 },
];

beforeEach(async () => {
  await clearFirestore();
  await db.doc('config/regions').set({ list: [{ id: 'seongsu', name: '성수', gu: '성동구', dongs: ['성수'] }] });
});

test('카카오 결과를 지역 판정 후 반환하고 식당 문서 생성', async () => {
  const kakao = jest.fn().mockResolvedValue(places);
  const res = await searchPlacesCore(db, kakao, { query: '찐', lat: 37.5, lng: 127 }, NOW);
  expect(res.map((r) => [r.placeId, r.region])).toEqual([['111', 'seongsu'], ['999', null]]);
  expect(kakao).toHaveBeenCalledWith('찐', { lat: 37.5, lng: 127 });
  const doc = (await db.doc('restaurants/111').get()).data()!;
  expect(doc).toMatchObject({ name: '성수 찐국밥', region: 'seongsu', roadAddress: '서울 성동구 연무장길 10' });
  expect(typeof doc.geohash).toBe('string');
  expect(doc.category).toBe('한식 · 국밥');
  expect(res[0].category).toBe('한식 · 국밥');
});

test('위치가 없으면 베타 지역 중심으로 검색', async () => {
  const kakao = jest.fn().mockResolvedValue(places);
  await searchPlacesCore(db, kakao, { query: '찐' }, NOW);
  expect(kakao).toHaveBeenCalledWith('찐', DEFAULT_NEAR);
  expect(DEFAULT_NEAR).toEqual({ lat: 37.5446, lng: 127.0557 });
});

test('7일 내 같은 검색은 캐시 사용', async () => {
  const kakao = jest.fn().mockResolvedValue(places);
  await searchPlacesCore(db, kakao, { query: '찐', lat: 37.501, lng: 127.001 }, NOW);
  const res = await searchPlacesCore(db, kakao, { query: '찐', lat: 37.502, lng: 127.002 }, new Date(NOW.getTime() + 6 * 86_400_000));
  expect(kakao).toHaveBeenCalledTimes(1);
  expect(res.map((r) => r.placeId).sort()).toEqual(['111', '999']);
});

test('7일 지나면 다시 호출', async () => {
  const kakao = jest.fn().mockResolvedValue(places);
  await searchPlacesCore(db, kakao, { query: '찐' }, NOW);
  await searchPlacesCore(db, kakao, { query: '찐' }, new Date(NOW.getTime() + 8 * 86_400_000));
  expect(kakao).toHaveBeenCalledTimes(2);
});

test('재검색해도 집계 필드 보존', async () => {
  await db.doc('restaurants/111').set({ scoreSum: 25.5, reviewCount: 3, realScore: 8.5 });
  await searchPlacesCore(db, jest.fn().mockResolvedValue(places), { query: '찐' }, NOW);
  expect((await db.doc('restaurants/111').get()).data()).toMatchObject({ scoreSum: 25.5, reviewCount: 3, realScore: 8.5, name: '성수 찐국밥' });
});

test('빈 검색어 거절', async () => {
  await expect(searchPlacesCore(db, jest.fn(), { query: '  ' }, NOW)).rejects.toMatchObject({ code: 'invalid-argument' });
});

test('카카오 실패는 unavailable', async () => {
  await expect(searchPlacesCore(db, jest.fn().mockRejectedValue(new Error('kakao 429')), { query: '찐' }, NOW))
    .rejects.toMatchObject({ code: 'unavailable', message: 'kakao_unavailable' });
});
