import { Auth, getAuth } from 'firebase-admin/auth';
import { Firestore, FieldValue, getFirestore } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { KakaoProfile, kakaoMe } from './kakao';
import { emptyRanking } from './scoring';
import { titleFor } from './title';
import { REGION } from './config';

export function newUserDoc(displayName: string | undefined, rand: () => number = Math.random): Record<string, unknown> {
  return {
    nickname: displayName?.trim().slice(0, 20) || `찐린이${Math.floor(rand() * 9000 + 1000)}`,
    title: titleFor(0),
    likesReceived: 0,
    verifiedReviewCount: 0,
    ranking: emptyRanking(),
    dailyReviewCount: 0,
    dailyReviewDate: '',
    createdAt: FieldValue.serverTimestamp(),
  };
}

export async function kakaoLoginCore(auth: Auth, me: (token: string) => Promise<KakaoProfile>, raw: unknown): Promise<{ token: string }> {
  const accessToken = (raw as { accessToken?: unknown } | null)?.accessToken;
  if (typeof accessToken !== 'string' || !accessToken) throw new HttpsError('invalid-argument', 'accessToken');
  let profile: KakaoProfile;
  try {
    profile = await me(accessToken);
  } catch {
    throw new HttpsError('unauthenticated', 'kakao_invalid_token');
  }
  const uid = `kakao:${profile.id}`;
  try {
    await auth.getUser(uid);
  } catch (e) {
    if ((e as { code?: string }).code !== 'auth/user-not-found') throw e;
    await auth.createUser({ uid, displayName: profile.nickname ?? undefined });
  }
  return { token: await auth.createCustomToken(uid) };
}

export async function ensureUserCore(db: Firestore, uid: string, displayName: string | undefined): Promise<void> {
  const ref = db.doc(`users/${uid}`);
  await db.runTransaction(async (tx) => {
    if (!(await tx.get(ref)).exists) tx.set(ref, newUserDoc(displayName));
  });
}

export const kakaoLogin = onCall({ region: REGION }, (req) => kakaoLoginCore(getAuth(), (t) => kakaoMe(t), req.data));

export const ensureUser = onCall({ region: REGION }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'login_required');
  await ensureUserCore(getFirestore(), req.auth.uid, req.auth.token.name as string | undefined);
  return { ok: true };
});
