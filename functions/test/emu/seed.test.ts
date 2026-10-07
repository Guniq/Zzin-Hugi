import { testDb, clearFirestore } from './helpers';
import { runSeed } from '../../src/dev/seed';

const db = testDb();
const NOW = new Date('2026-10-07T03:00:00Z');

beforeEach(async () => {
  await clearFirestore();
  await runSeed(db, NOW);
});

test('앱 홈 쿼리: 찐점수 높은 순, 후기 없는 식당 제외', async () => {
  const snap = await db.collection('restaurants').where('region', '==', 'hwagok').orderBy('realScore', 'desc').get();
  expect(snap.docs.map((x) => x.id)).toEqual(['fake-1', 'fake-3', 'fake-2', 'fake-4']);
});

test('앱 홈 쿼리: 거품 큰 순', async () => {
  const snap = await db.collection('restaurants').where('region', '==', 'hwagok').orderBy('bubble', 'desc').get();
  expect(snap.docs.slice(0, 2).map((x) => x.id)).toEqual(['fake-4', 'fake-2']);
});

test('상세 후기 쿼리: 따봉순', async () => {
  const snap = await db.collection('reviews').where('restaurantId', '==', 'fake-4').orderBy('likeCount', 'desc').get();
  expect(snap.docs.map((x) => x.data().uid)).toEqual(['seed1', 'seed2', 'seed3']);
});

test('대마왕·지역 문서', async () => {
  expect((await db.doc('crowns/2026-10_hwagok').get()).data()).toMatchObject({ uid: 'seed1', status: 'confirmed' });
  expect((await db.doc('config/regions').get()).data()!.list[0]).toMatchObject({ id: 'hwagok' });
});
