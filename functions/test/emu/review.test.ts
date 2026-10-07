import { testDb, clearFirestore } from './helpers';
import { submitReviewCore } from '../../src/review';
import { OcrReceipt } from '../../src/receipt';

const db = testDb();
const NOW = new Date('2026-10-07T03:00:00Z'); // KST 2026-10-07

const PLACES: Record<string, { name: string; address: string; roadAddress: string; region: string | null }> = {
  p1: { name: '성수 찐국밥', address: '서울 성동구 성수동2가 300-1', roadAddress: '서울 성동구 연무장길 10', region: 'seongsu' },
  p2: { name: '성수 찐카페', address: '서울 성동구 성수동1가 10', roadAddress: '서울 성동구 성수이로 20', region: 'seongsu' },
  p3: { name: '성수 찐면옥', address: '서울 성동구 성수동1가 20', roadAddress: '서울 성동구 성수이로 30', region: 'seongsu' },
  far: { name: '강남 찐면', address: '서울 강남구 역삼동 1', roadAddress: '', region: null },
};

// 영수증 경로 규칙: receipts/{uid}/{placeId}-{승인번호}.jpg → 해당 식당 정상 영수증
const ocr = async (path: string): Promise<OcrReceipt> => {
  const [placeId, approvalNo] = path.split('/')[2].replace('.jpg', '').split('-');
  const p = PLACES[placeId];
  return { storeName: p.name, address: p.roadAddress || p.address, date: '2026-10-06', total: 10000, approvalNo };
};
const deps = { ocr };

const input = (uid: string, placeId: string, approvalNo: string, extra: object = {}) => ({
  placeId, receiptPath: `receipts/${uid}/${placeId}-${approvalNo}.jpg`, tier: 'best', rankIndex: 0,
  eventJoined: false, eventStars: null, text: '국물이 진하고 고기가 많아요', photos: [], ...extra,
});
const user = (uid: string) => db.doc(`users/${uid}`).get().then((s) => s.data()!);
const rest = (id: string) => db.doc(`restaurants/${id}`).get().then((s) => s.data()!);
const review = (id: string) => db.doc(`reviews/${id}`).get().then((s) => s.data());

beforeEach(async () => {
  await clearFirestore();
  for (const [id, p] of Object.entries(PLACES)) await db.doc(`restaurants/${id}`).set(p);
  for (const uid of ['u1', 'u2', 'u3']) {
    await db.doc(`users/${uid}`).set({ verifiedReviewCount: 0, ranking: { best: [], ok: [], bad: [] }, dailyReviewCount: 0, dailyReviewDate: '' });
  }
});

test('첫 후기 작성', async () => {
  const res = await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1001'), NOW);
  expect(res).toEqual({ reviewId: 'u1_p1' });
  expect(await review('u1_p1')).toMatchObject({ uid: 'u1', restaurantId: 'p1', region: 'seongsu', tier: 'best', personalScore: 8.5, visitDate: '2026-10-06', likeCount: 0 });
  expect(await user('u1')).toMatchObject({ verifiedReviewCount: 1, ranking: { best: ['p1'], ok: [], bad: [] }, dailyReviewCount: 1, dailyReviewDate: '2026-10-07' });
  expect(await rest('p1')).toMatchObject({ scoreSum: 8.5, reviewCount: 1, eventStarSum: 0, eventReviewCount: 0, realScore: null });
});

test('새 식당을 1위로 넣으면 기존 후기·식당 점수 재계산', async () => {
  await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1001'), NOW);
  await submitReviewCore(db, deps, 'u1', input('u1', 'p2', '1002', { rankIndex: 0 }), NOW);
  expect((await review('u1_p1'))!.personalScore).toBe(7.8);
  expect((await review('u1_p2'))!.personalScore).toBe(9.3);
  expect((await rest('p1')).scoreSum).toBe(7.8);
  expect((await rest('p2')).scoreSum).toBe(9.3);
});

test('등급 이동: 최고→별로 시 남은 최고 식당 점수도 재계산', async () => {
  await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1001'), NOW);
  await submitReviewCore(db, deps, 'u1', input('u1', 'p2', '1002', { rankIndex: 1 }), NOW); // best: [p1, p2]
  await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1003', { tier: 'bad' }), NOW); // 재방문, best: [p2], bad: [p1]
  expect((await user('u1')).ranking).toEqual({ best: ['p2'], ok: [], bad: ['p1'] });
  expect((await review('u1_p2'))!.personalScore).toBe(8.5);
  expect((await rest('p2')).scoreSum).toBe(8.5);
  expect((await rest('p1')).scoreSum).toBe(2);
});

test('재방문: 카운트 중복 없음, 이벤트 점수 교체', async () => {
  await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1001', { eventJoined: true, eventStars: 5 }), NOW);
  await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1002', { eventJoined: true, eventStars: 3 }), NOW);
  expect(await rest('p1')).toMatchObject({ reviewCount: 1, eventReviewCount: 1, eventStarSum: 3 });
  expect((await user('u1')).verifiedReviewCount).toBe(1);
  await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1003'), NOW);
  expect(await rest('p1')).toMatchObject({ reviewCount: 1, eventReviewCount: 0, eventStarSum: 0 });
});

test('3명이 쓰면 찐점수·거품지수 계산', async () => {
  for (const [i, uid] of ['u1', 'u2', 'u3'].entries()) {
    await submitReviewCore(db, deps, uid, input(uid, 'p1', `200${i}`, { tier: 'ok', eventJoined: true, eventStars: 5 }), NOW);
  }
  expect(await rest('p1')).toMatchObject({ reviewCount: 3, realScore: 5.5, eventScore: 10, bubble: 4.5 });
});

test('같은 영수증 재사용은 duplicate, 아무것도 안 바뀜', async () => {
  await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1001'), NOW);
  await expect(submitReviewCore(db, deps, 'u2', { ...input('u2', 'p1', '1001') }, NOW))
    .rejects.toMatchObject({ code: 'already-exists', message: 'duplicate' });
  expect(await review('u2_p1')).toBeUndefined();
  expect((await rest('p1')).reviewCount).toBe(1);
});

test('하루 5개 제한', async () => {
  await db.doc('users/u1').update({ dailyReviewDate: '2026-10-07', dailyReviewCount: 5 });
  await expect(submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1001'), NOW))
    .rejects.toMatchObject({ code: 'resource-exhausted', message: 'daily_limit' });
});

test('어제 카운트는 오늘 초기화', async () => {
  await db.doc('users/u1').update({ dailyReviewDate: '2026-10-06', dailyReviewCount: 5 });
  await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1001'), NOW);
  expect((await user('u1')).dailyReviewCount).toBe(1);
});

test('베타 지역 밖 식당 거절', async () => {
  await expect(submitReviewCore(db, deps, 'u1', input('u1', 'far', '1001'), NOW))
    .rejects.toMatchObject({ code: 'failed-precondition', message: 'out_of_region' });
});

test('검색 안 된 식당은 not-found', async () => {
  await expect(submitReviewCore(db, deps, 'u1', { ...input('u1', 'p1', '1001'), placeId: 'nope' }, NOW))
    .rejects.toMatchObject({ code: 'not-found', message: 'place_not_found' });
});

test('다른 가게 영수증은 store_mismatch, 기록 없음', async () => {
  await expect(submitReviewCore(db, deps, 'u1', { ...input('u1', 'p2', '1001'), placeId: 'p1' }, NOW))
    .rejects.toMatchObject({ code: 'failed-precondition', message: 'store_mismatch' });
  expect(await review('u1_p1')).toBeUndefined();
});

test('OCR 장애는 unavailable', async () => {
  const broken = { ocr: async () => { throw new Error('clova 500'); } };
  await expect(submitReviewCore(db, broken, 'u1', input('u1', 'p1', '1001'), NOW))
    .rejects.toMatchObject({ code: 'unavailable', message: 'ocr_unavailable' });
});
