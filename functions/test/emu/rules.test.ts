import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { initializeTestEnvironment, assertFails, assertSucceeds, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, serverTimestamp } from 'firebase/firestore';
import { ref, uploadBytes, getBytes } from 'firebase/storage';

const root = resolve(__dirname, '../../..');
let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-zzinhugi',
    firestore: { rules: readFileSync(resolve(root, 'firestore.rules'), 'utf8') },
    storage: { rules: readFileSync(resolve(root, 'storage.rules'), 'utf8') },
  });
});
afterAll(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/alice'), { verifiedReviewCount: 1 });
    await setDoc(doc(db, 'users/bob'), { verifiedReviewCount: 0 });
    await setDoc(doc(db, 'reviews/carol_p1'), { uid: 'carol' });
    await setDoc(doc(db, 'reviews/alice_p1'), { uid: 'alice' });
    await setDoc(doc(db, 'restaurants/p1'), { name: '찐국밥' });
    await setDoc(doc(db, 'receiptKeys/h1'), { uid: 'alice' });
    await setDoc(doc(db, 'config/regions'), { list: [] });
  });
});

const fs = (uid?: string) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const st = (uid?: string) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).storage();
const img = new Uint8Array([1, 2, 3]);

describe('따봉', () => {
  test('인증 후기 보유자는 남의 후기에 따봉 가능', () =>
    assertSucceeds(setDoc(doc(fs('alice'), 'reviews/carol_p1/likes/alice'), { createdAt: serverTimestamp() })));
  test('인증 후기 없으면 불가', () =>
    assertFails(setDoc(doc(fs('bob'), 'reviews/carol_p1/likes/bob'), { createdAt: serverTimestamp() })));
  test('본인 후기는 불가', () =>
    assertFails(setDoc(doc(fs('alice'), 'reviews/alice_p1/likes/alice'), { createdAt: serverTimestamp() })));
  test('남의 uid로는 불가', () =>
    assertFails(setDoc(doc(fs('alice'), 'reviews/carol_p1/likes/bob'), { createdAt: serverTimestamp() })));
  test('추가 필드 불가', () =>
    assertFails(setDoc(doc(fs('alice'), 'reviews/carol_p1/likes/alice'), { createdAt: serverTimestamp(), x: 1 })));
  test('없는 후기는 불가', () =>
    assertFails(setDoc(doc(fs('alice'), 'reviews/nope/likes/alice'), { createdAt: serverTimestamp() })));
  test('본인 따봉만 취소', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => { await setDoc(doc(ctx.firestore(), 'reviews/carol_p1/likes/alice'), { createdAt: new Date() }); });
    await assertFails(deleteDoc(doc(fs('bob'), 'reviews/carol_p1/likes/alice')));
    await assertSucceeds(deleteDoc(doc(fs('alice'), 'reviews/carol_p1/likes/alice')));
  });
});

describe('읽기·쓰기 범위', () => {
  test('로그인 유저는 식당·후기·유저 읽기', async () => {
    await assertSucceeds(getDoc(doc(fs('bob'), 'restaurants/p1')));
    await assertSucceeds(getDoc(doc(fs('bob'), 'reviews/carol_p1')));
    await assertSucceeds(getDoc(doc(fs('bob'), 'users/alice')));
  });
  test('비로그인은 읽기 불가', () => assertFails(getDoc(doc(fs(), 'restaurants/p1'))));
  test('후기·식당 직접 쓰기 불가', async () => {
    await assertFails(setDoc(doc(fs('alice'), 'reviews/alice_p2'), { uid: 'alice' }));
    await assertFails(setDoc(doc(fs('alice'), 'restaurants/p1'), { realScore: 10 }));
    await assertFails(setDoc(doc(fs('alice'), 'users/alice'), { verifiedReviewCount: 99 }));
  });
  test('receiptKeys·config 읽기 불가', async () => {
    await assertFails(getDoc(doc(fs('alice'), 'receiptKeys/h1')));
    await assertFails(getDoc(doc(fs('alice'), 'config/regions')));
  });
  test('신고는 본인 명의로만', async () => {
    await assertSucceeds(setDoc(doc(fs('bob'), 'reports/r1'), { reviewId: 'carol_p1', reporterUid: 'bob', reason: '광고', createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(fs('bob'), 'reports/r2'), { reviewId: 'carol_p1', reporterUid: 'alice', reason: '광고', createdAt: serverTimestamp() }));
  });
});

describe('Storage', () => {
  test('본인 폴더에 영수증 업로드 가능, 읽기는 본인도 불가', async () => {
    await assertSucceeds(uploadBytes(ref(st('alice'), 'receipts/alice/r1.jpg'), img, { contentType: 'image/jpeg' }));
    await assertFails(getBytes(ref(st('alice'), 'receipts/alice/r1.jpg')));
  });
  test('남의 폴더 업로드 불가', () =>
    assertFails(uploadBytes(ref(st('alice'), 'receipts/bob/r1.jpg'), img, { contentType: 'image/jpeg' })));
  test('이미지 아닌 파일 불가', () =>
    assertFails(uploadBytes(ref(st('alice'), 'photos/alice/a.txt'), img, { contentType: 'text/plain' })));
  test('사진은 비로그인도 읽기 가능', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => { await uploadBytes(ref(ctx.storage(), 'photos/alice/p.jpg'), img, { contentType: 'image/jpeg' }); });
    await assertSucceeds(getBytes(ref(st(), 'photos/alice/p.jpg')));
  });
});
