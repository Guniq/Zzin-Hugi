import { testDb, clearFirestore } from './helpers';
import { pickCrowns } from '../../src/crown';

const db = testDb();
const NOW = new Date('2026-09-30T15:00:00Z'); // KST 10/1 00:00

beforeEach(async () => {
  await clearFirestore();
  await db.doc('config/regions').set({ list: [
    { id: 'seongsu', name: '성수', gu: '성동구', dongs: ['성수'] },
    { id: 'gangnam', name: '강남', gu: '강남구', dongs: ['역삼'] },
  ] });
  const lm = (month: string, region: string, uid: string, likes: number) =>
    db.doc(`likeMonths/${month}_${region}_${uid}`).set({ month, region, uid, likes });
  await lm('2026-09', 'seongsu', 'a', 5);
  await lm('2026-09', 'seongsu', 'b', 12);
  await lm('2026-08', 'seongsu', 'c', 99); // 다른 달
  await lm('2026-09', 'gangnam', 'd', 0); // 0따봉은 제외
});

test('지역별 지난달 1위를 pending으로 기록', async () => {
  await pickCrowns(db, NOW);
  expect((await db.doc('crowns/2026-10_seongsu').get()).data()).toEqual({
    uid: 'b', likes: 12, region: 'seongsu', scoreMonth: '2026-09', displayMonth: '2026-10', status: 'pending',
  });
  expect((await db.doc('crowns/2026-10_gangnam').get()).exists).toBe(false);
});
