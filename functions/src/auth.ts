import { Auth, getAuth } from 'firebase-admin/auth';
import { Firestore, FieldValue, getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { KakaoProfile, kakaoMe } from './kakao';
import { kakaoAuthorizeUrl, kakaoExchangeCode } from './kakaoOauth';
import { isFakeKakao, fakeAuthorizeUrl, fakeExchange, fakeKakaoMe } from './dev/fake';
import { titleFor } from './title';
import { REGION, KAKAO_REST_KEY, KAKAO_CLIENT_SECRET } from './config';

export function newUserDoc(displayName: string | undefined, rand: () => number = Math.random): Record<string, unknown> {
  return {
    nickname: displayName?.trim().slice(0, 20) || `찐린이${Math.floor(rand() * 9000 + 1000)}`,
    title: titleFor(0),
    likesReceived: 0,
    verifiedReviewCount: 0,
    dailyReviewCount: 0,
    dailyReviewDate: '',
    createdAt: FieldValue.serverTimestamp(),
  };
}

/** 로그인 뒤 돌아올 주소. 카카오 콘솔에 등록한 Redirect URI 와 같아야 한다(카카오가 한 번 더 검사). */
export function isValidRedirectUri(u: unknown): u is string {
  if (typeof u !== 'string' || u.length > 200) return false;
  try {
    const x = new URL(u);
    return (x.protocol === 'http:' || x.protocol === 'https:') && !x.hash && !x.username && !x.password;
  } catch {
    return false;
  }
}

/** 앱이 만든 임의 문자열(CSRF 방지). */
export const STATE_RE = /^[A-Za-z0-9_-]{16,128}$/;

export type CodeExchange = (code: string, redirectUri: string) => Promise<string>;

/**
 * 카카오 액세스 토큰(모바일 SDK) 또는 인가 코드(웹)로 로그인한다.
 * 입력: `{accessToken}` 또는 `{code, redirectUri}`. 코드는 [exchange] 로 토큰으로 바꾼다.
 */
export async function kakaoLoginCore(
  auth: Auth,
  me: (token: string) => Promise<KakaoProfile>,
  raw: unknown,
  exchange?: CodeExchange,
): Promise<{ token: string }> {
  const d = (raw ?? {}) as { accessToken?: unknown; code?: unknown; redirectUri?: unknown };
  let accessToken: string;
  if (typeof d.accessToken === 'string' && d.accessToken) {
    accessToken = d.accessToken;
  } else if (typeof d.code === 'string' && d.code && isValidRedirectUri(d.redirectUri) && exchange) {
    try {
      accessToken = await exchange(d.code, d.redirectUri);
    } catch (e) {
      logger.error('kakao code exchange failed', { error: e instanceof Error ? e.message : String(e) });
      throw new HttpsError('unauthenticated', 'kakao_code_rejected');
    }
  } else {
    throw new HttpsError('invalid-argument', 'accessToken');
  }
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

/** 앱이 카카오로 보낼 인가 주소를 만들어 준다. REST 키가 앱 번들에 들어가지 않게 서버에서 만든다. */
export function kakaoLoginUrlCore(buildUrl: (redirectUri: string, state: string) => string, raw: unknown): { url: string } {
  const d = (raw ?? {}) as { redirectUri?: unknown; state?: unknown };
  if (!isValidRedirectUri(d.redirectUri)) throw new HttpsError('invalid-argument', 'redirectUri');
  if (typeof d.state !== 'string' || !STATE_RE.test(d.state)) throw new HttpsError('invalid-argument', 'state');
  return { url: buildUrl(d.redirectUri, d.state) };
}

export async function ensureUserCore(db: Firestore, uid: string, displayName: string | undefined): Promise<void> {
  const ref = db.doc(`users/${uid}`);
  await db.runTransaction(async (tx) => {
    if (!(await tx.get(ref)).exists) tx.set(ref, newUserDoc(displayName));
  });
}

// 'none' 또는 빈 값이면 Client Secret 을 쓰지 않는 앱으로 본다.
const clientSecret = (): string | undefined => {
  const v = KAKAO_CLIENT_SECRET.value();
  return v && v !== 'none' ? v : undefined;
};

export const kakaoLoginUrl = onCall({ region: REGION, secrets: [KAKAO_REST_KEY] }, (req) =>
  kakaoLoginUrlCore(isFakeKakao() ? fakeAuthorizeUrl : (r, s) => kakaoAuthorizeUrl(KAKAO_REST_KEY.value(), r, s), req.data),
);

export const kakaoLogin = onCall({ region: REGION, secrets: [KAKAO_REST_KEY, KAKAO_CLIENT_SECRET] }, (req) => {
  const fake = isFakeKakao();
  const me = fake ? fakeKakaoMe : (t: string) => kakaoMe(t);
  const exchange: CodeExchange = fake ? fakeExchange : (code, redirectUri) => kakaoExchangeCode(code, redirectUri, KAKAO_REST_KEY.value(), clientSecret());
  return kakaoLoginCore(getAuth(), me, req.data, exchange);
});

export const ensureUser = onCall({ region: REGION }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'login_required');
  // 커스텀 토큰(카카오)으로 로그인한 경우 토큰에 name 이 없을 수 있어서, 계정 정보의 표시 이름을 쓴다.
  const name = (req.auth.token.name as string | undefined) ?? (await getAuth().getUser(req.auth.uid)).displayName ?? undefined;
  await ensureUserCore(getFirestore(), req.auth.uid, name);
  return { ok: true };
});
