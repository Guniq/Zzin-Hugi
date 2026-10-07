import { testDb, clearFirestore } from './helpers';
import { applyLike } from '../../src/likes';

const db = testDb();
const NOW = new Date('2026-10-07T03:00:00Z');

beforeEach(async () => {
  await clearFirestore();
  await db.doc('reviews/carol_p1').set({ uid: 'carol', region: 'seongsu', likeCount: 0 });
  await db.doc('users/carol').set({ likesReceived: 9, title: '찐린이' });
});

test('따봉 +1: 후기·유저·월간 집계, 10개 되면 칭호 승급', async () => {
  await applyLike(db, 'carol_p1', 1, NOW);
  expect((await db.doc('reviews/carol_p1').get()).data()!.likeCount).toBe(1);
  expect((await db.doc('users/carol').get()).data()).toMatchObject({ likesReceived: 10, title: '찐후기러' });
  expect((await db.doc('likeMonths/2026-10_seongsu_carol').get()).data()).toEqual({ uid: 'carol', region: 'seongsu', month: '2026-10', likes: 1 });
});

test('따봉 취소 -1: 칭호 강등, 0 아래로 안 내려감', async () => {
  await applyLike(db, 'carol_p1', 1, NOW);
  await applyLike(db, 'carol_p1', -1, NOW);
  expect((await db.doc('users/carol').get()).data()).toMatchObject({ likesReceived: 9, title: '찐린이' });
  await db.doc('users/carol').update({ likesReceived: 0 });
  await applyLike(db, 'carol_p1', -1, NOW);
  expect((await db.doc('users/carol').get()).data()!.likesReceived).toBe(0);
});

test('삭제된 후기는 무시', async () => {
  await expect(applyLike(db, 'nope', 1, NOW)).resolves.toBeUndefined();
});
