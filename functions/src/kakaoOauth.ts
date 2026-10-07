// 카카오 로그인(웹, 인가 코드 방식)의 서버 쪽 두 단계.
//   1) 인가 URL 만들기  → 앱이 그 주소로 이동해 카카오에서 로그인
//   2) 돌아온 인가 코드를 액세스 토큰으로 교환 (REST 키·Client Secret 은 서버에만 둔다)

export function kakaoAuthorizeUrl(restKey: string, redirectUri: string, state: string): string {
  const p = new URLSearchParams({ client_id: restKey, redirect_uri: redirectUri, response_type: 'code', state });
  return `https://kauth.kakao.com/oauth/authorize?${p}`;
}

/** 인가 코드 → 액세스 토큰. 실패 메시지에는 키·시크릿을 담지 않는다. */
export async function kakaoExchangeCode(
  code: string,
  redirectUri: string,
  restKey: string,
  clientSecret: string | undefined,
  fetchFn: typeof fetch = fetch,
): Promise<string> {
  const body = new URLSearchParams({ grant_type: 'authorization_code', client_id: restKey, redirect_uri: redirectUri, code });
  if (clientSecret) body.set('client_secret', clientSecret);
  const res = await fetchFn('https://kauth.kakao.com/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8' },
    body,
    signal: AbortSignal.timeout(8_000),
  });
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const j: any = await res.json().catch(() => ({}));
  if (!res.ok || typeof j.access_token !== 'string') {
    throw new Error(`kakao_token ${res.status}: ${j.error_description ?? j.error ?? ''}`.trim());
  }
  return j.access_token;
}
