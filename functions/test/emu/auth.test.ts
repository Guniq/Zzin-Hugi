import { getAuth } from 'firebase-admin/auth';
import { testDb, clearFirestore } from './helpers';
import { kakaoLoginCore, ensureUserCore, newUserDoc } from '../../src/auth';

const db = testDb();
const auth = getAuth();

beforeEach(async () => {
  await clearFirestore();
  await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/projects/demo-zzinhugi/accounts`, { method: 'DELETE' });
});

test('카카오 로그인: 유저 생성 후 커스텀 토큰', async () => {
  const me = jest.fn().mockResolvedValue({ id: '42', nickname: '찐이' });
  const { token } = await kakaoLoginCore(auth, me, { accessToken: 'tok' });
  expect(typeof token).toBe('string');
  expect((await auth.getUser('kakao:42')).displayName).toBe('찐이');
  await kakaoLoginCore(auth, me, { accessToken: 'tok' }); // 두 번째는 기존 유저 재사용
  expect((await auth.listUsers()).users).toHaveLength(1);
});

test('카카오 토큰 무효는 unauthenticated', async () => {
  const me = jest.fn().mockRejectedValue(new Error('kakao_me 401'));
  await expect(kakaoLoginCore(auth, me, { accessToken: 'bad' })).rejects.toMatchObject({ code: 'unauthenticated', message: 'kakao_invalid_token' });
});

test('accessToken 누락은 invalid-argument', async () => {
  await expect(kakaoLoginCore(auth, jest.fn(), {})).rejects.toMatchObject({ code: 'invalid-argument' });
});

test('ensureUser: 없으면 생성, 있으면 유지', async () => {
  await ensureUserCore(db, 'u1', '찐이');
  expect((await db.doc('users/u1').get()).data()).toMatchObject({ nickname: '찐이', title: '찐린이', likesReceived: 0, verifiedReviewCount: 0 });
  await db.doc('users/u1').update({ likesReceived: 7 });
  await ensureUserCore(db, 'u1', '다른이름');
  expect((await db.doc('users/u1').get()).data()).toMatchObject({ nickname: '찐이', likesReceived: 7 });
});

test('닉네임 없으면 찐린이+4자리', () => {
  expect(newUserDoc(undefined, () => 0).nickname).toBe('찐린이1000');
});
