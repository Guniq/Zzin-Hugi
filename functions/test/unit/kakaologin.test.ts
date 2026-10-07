import { isValidRedirectUri, kakaoLoginCore, kakaoLoginUrlCore, STATE_RE } from '../../src/auth';
import { kakaoAuthorizeUrl, kakaoExchangeCode } from '../../src/kakaoOauth';

describe('isValidRedirectUri', () => {
  test('http/https 주소만, 해시·계정정보 없이', () => {
    expect(isValidRedirectUri('http://localhost:5050/')).toBe(true);
    expect(isValidRedirectUri('https://zzin.example/app/')).toBe(true);
    expect(isValidRedirectUri('javascript:alert(1)')).toBe(false);
    expect(isValidRedirectUri('http://a.com/#x')).toBe(false);
    expect(isValidRedirectUri('http://user:pw@a.com/')).toBe(false);
    expect(isValidRedirectUri('not a url')).toBe(false);
    expect(isValidRedirectUri(123)).toBe(false);
    expect(isValidRedirectUri('http://a.com/' + 'x'.repeat(200))).toBe(false);
  });
});

describe('kakaoLoginUrlCore', () => {
  const build = (r: string, s: string) => `https://kauth.example/authorize?r=${encodeURIComponent(r)}&s=${s}`;
  test('주소와 state 를 검증한 뒤 URL 을 만든다', () => {
    const state = 'abcdefghijklmnopqrstuvwx';
    expect(STATE_RE.test(state)).toBe(true);
    expect(kakaoLoginUrlCore(build, { redirectUri: 'http://localhost:5050/', state }).url).toContain('s=' + state);
  });
  test('잘못된 redirectUri / state 는 거절', () => {
    expect(() => kakaoLoginUrlCore(build, { redirectUri: 'x', state: 'abcdefghijklmnopqrstuvwx' })).toThrow();
    expect(() => kakaoLoginUrlCore(build, { redirectUri: 'http://localhost:5050/', state: 'short' })).toThrow();
    expect(() => kakaoLoginUrlCore(build, { redirectUri: 'http://localhost:5050/', state: 'has space has space has space' })).toThrow();
  });
});

describe('kakaoLoginCore 인가 코드', () => {
  const auth = {
    getUser: jest.fn().mockRejectedValue({ code: 'auth/user-not-found' }),
    createUser: jest.fn().mockResolvedValue({}),
    createCustomToken: jest.fn().mockResolvedValue('custom-token'),
  };
  const me = jest.fn().mockResolvedValue({ id: '42', nickname: '찐이' });

  test('code + redirectUri 를 토큰으로 교환해 로그인', async () => {
    const exchange = jest.fn().mockResolvedValue('kakao-access');
    const r = await kakaoLoginCore(auth as never, me, { code: 'C', redirectUri: 'http://localhost:5050/' }, exchange);
    expect(r).toEqual({ token: 'custom-token' });
    expect(exchange).toHaveBeenCalledWith('C', 'http://localhost:5050/');
    expect(me).toHaveBeenCalledWith('kakao-access');
    expect(auth.createUser).toHaveBeenCalledWith({ uid: 'kakao:42', displayName: '찐이' });
  });

  test('교환 실패는 kakao_code_rejected', async () => {
    const exchange = jest.fn().mockRejectedValue(new Error('kakao_token 400: KOE320'));
    await expect(kakaoLoginCore(auth as never, me, { code: 'C', redirectUri: 'http://localhost:5050/' }, exchange)).rejects.toMatchObject({
      code: 'unauthenticated',
      message: 'kakao_code_rejected',
    });
  });

  test('redirectUri 가 잘못되면 교환하지 않고 거절', async () => {
    const exchange = jest.fn();
    await expect(kakaoLoginCore(auth as never, me, { code: 'C', redirectUri: 'javascript:1' }, exchange)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(exchange).not.toHaveBeenCalled();
  });

  test('기존 accessToken 방식도 그대로 동작', async () => {
    const r = await kakaoLoginCore(auth as never, me, { accessToken: 'T' });
    expect(r).toEqual({ token: 'custom-token' });
  });
});

describe('kakaoOauth', () => {
  test('인가 URL 에 client_id·redirect_uri·state 가 들어감', () => {
    const u = new URL(kakaoAuthorizeUrl('REST', 'http://localhost:5050/', 'STATE1234567890123456'));
    expect(u.origin + u.pathname).toBe('https://kauth.kakao.com/oauth/authorize');
    expect(u.searchParams.get('client_id')).toBe('REST');
    expect(u.searchParams.get('redirect_uri')).toBe('http://localhost:5050/');
    expect(u.searchParams.get('response_type')).toBe('code');
    expect(u.searchParams.get('state')).toBe('STATE1234567890123456');
  });

  test('코드 교환: 본문과 시크릿 처리, 실패 메시지에 시크릿 없음', async () => {
    const ok = jest.fn().mockResolvedValue({ ok: true, status: 200, json: async () => ({ access_token: 'AT' }) });
    expect(await kakaoExchangeCode('C', 'http://localhost:5050/', 'REST', 'SEC', ok as unknown as typeof fetch)).toBe('AT');
    const body = ok.mock.calls[0][1].body as URLSearchParams;
    expect(body.get('grant_type')).toBe('authorization_code');
    expect(body.get('client_secret')).toBe('SEC');

    const noSecret = jest.fn().mockResolvedValue({ ok: true, status: 200, json: async () => ({ access_token: 'AT' }) });
    await kakaoExchangeCode('C', 'http://localhost:5050/', 'REST', undefined, noSecret as unknown as typeof fetch);
    expect((noSecret.mock.calls[0][1].body as URLSearchParams).has('client_secret')).toBe(false);

    const bad = jest.fn().mockResolvedValue({ ok: false, status: 400, json: async () => ({ error: 'invalid_grant', error_description: 'bad code' }) });
    const err = await kakaoExchangeCode('C', 'http://localhost:5050/', 'REST', 'SECRETVALUE', bad as unknown as typeof fetch).catch((e) => e);
    expect(err.message).toBe('kakao_token 400: bad code');
    expect(err.message).not.toContain('SECRETVALUE');
  });
});
