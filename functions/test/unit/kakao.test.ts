import { parseKakaoKeyword, kakaoKeywordSearch, kakaoMe } from '../../src/kakao';

const body = {
  documents: [
    { id: '111', place_name: '성수 찐국밥', address_name: '서울 성동구 성수동2가 300-1', road_address_name: '서울 성동구 연무장길 10', x: '127.05', y: '37.54', category_group_code: 'FD6', category_name: '음식점 > 한식 > 국밥' },
    { id: '222', place_name: '찐카페', address_name: '서울 성동구 성수동1가 1', road_address_name: '', x: '127.04', y: '37.55', category_group_code: 'CE7', category_name: '음식점 > 카페' },
    { id: '333', place_name: '찐주차장', address_name: '서울 성동구 성수동1가 2', road_address_name: '', x: '127.0', y: '37.5', category_group_code: 'PK6' },
  ],
};

test('음식점·카페만 남기고 숫자 변환', () => {
  expect(parseKakaoKeyword(body)).toEqual([
    { placeId: '111', name: '성수 찐국밥', address: '서울 성동구 성수동2가 300-1', roadAddress: '서울 성동구 연무장길 10', category: '한식 · 국밥', lat: 37.54, lng: 127.05 },
    { placeId: '222', name: '찐카페', address: '서울 성동구 성수동1가 1', roadAddress: '', category: '카페', lat: 37.55, lng: 127.04 },
  ]);
});

test('위치 있으면 x/y/radius 포함, KakaoAK 헤더', async () => {
  const fetchFn = jest.fn().mockResolvedValue({ ok: true, json: async () => body });
  await kakaoKeywordSearch('국밥', { lat: 37.5, lng: 127.0 }, 'KEY', fetchFn as unknown as typeof fetch);
  const [url, init] = fetchFn.mock.calls[0];
  const u = new URL(url);
  expect(u.searchParams.get('query')).toBe('국밥');
  expect(u.searchParams.get('x')).toBe('127');
  expect(u.searchParams.get('y')).toBe('37.5');
  expect(init.headers.Authorization).toBe('KakaoAK KEY');
  expect(u.searchParams.get('sort')).toBe('distance');
});

test('위치 없으면 거리순 정렬 파라미터 없음', async () => {
  const fetchFn = jest.fn().mockResolvedValue({ ok: true, json: async () => body });
  await kakaoKeywordSearch('국밥', null, 'KEY', fetchFn as unknown as typeof fetch);
  const u = new URL(fetchFn.mock.calls[0][0]);
  expect(u.searchParams.has('sort')).toBe(false);
  expect(u.searchParams.has('x')).toBe(false);
});

test('category_name 이 없으면 빈 문자열', () => {
  const r = parseKakaoKeyword({ documents: [{ id: '1', place_name: 'a', address_name: 'b', road_address_name: '', x: '1', y: '2', category_group_code: 'FD6' }] });
  expect(r[0].category).toBe('');
});

test('kakaoMe는 id 문자열과 닉네임 반환', async () => {
  const fetchFn = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ id: 42, kakao_account: { profile: { nickname: '찐이' } } }) });
  expect(await kakaoMe('tok', fetchFn as unknown as typeof fetch)).toEqual({ id: '42', nickname: '찐이' });
  expect(fetchFn.mock.calls[0][1].headers.Authorization).toBe('Bearer tok');
});

test('kakaoMe 401은 throw', async () => {
  const fetchFn = jest.fn().mockResolvedValue({ ok: false, status: 401 });
  await expect(kakaoMe('bad', fetchFn as unknown as typeof fetch)).rejects.toThrow('kakao_me 401');
});

test('카카오 오류는 상태 코드와 카카오 메시지를 담아 던짐 (키는 담지 않음)', async () => {
  const fetchFn = jest.fn().mockResolvedValue({
    ok: false,
    status: 403,
    json: async () => ({ errorType: 'NotAuthorizedError', message: 'App(x) disabled OPEN_MAP_AND_LOCAL service.' }),
  });
  const err = await kakaoKeywordSearch('국밥', null, 'SECRETKEY', fetchFn as unknown as typeof fetch).catch((e) => e);
  expect(err.message).toBe('kakao 403: App(x) disabled OPEN_MAP_AND_LOCAL service.');
  expect(err.message).not.toContain('SECRETKEY');
});

test('오류 본문이 JSON 이 아니어도 상태 코드는 남김', async () => {
  const fetchFn = jest.fn().mockResolvedValue({ ok: false, status: 502, json: async () => { throw new Error('not json'); } });
  await expect(kakaoKeywordSearch('국밥', null, 'K', fetchFn as unknown as typeof fetch)).rejects.toThrow('kakao 502');
});
