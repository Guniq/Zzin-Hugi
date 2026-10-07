import { isFake, fakeKakaoSearch, fakeOcr, FAKE_PLACES } from '../../src/dev/fake';
import { verifyReceipt } from '../../src/receipt';
import { regionFor } from '../../src/address';
import { SEED_REGIONS } from '../../src/dev/seed';

const NOW = new Date('2026-10-07T03:00:00Z');

describe('isFake', () => {
  const saved = { f: process.env.FAKE_EXTERNALS, e: process.env.FUNCTIONS_EMULATOR };
  afterEach(() => {
    if (saved.f === undefined) delete process.env.FAKE_EXTERNALS;
    else process.env.FAKE_EXTERNALS = saved.f;
    if (saved.e === undefined) delete process.env.FUNCTIONS_EMULATOR;
    else process.env.FUNCTIONS_EMULATOR = saved.e;
  });
  test('에뮬레이터가 아니면 FAKE_EXTERNALS가 켜져 있어도 false', () => {
    process.env.FAKE_EXTERNALS = 'true';
    delete process.env.FUNCTIONS_EMULATOR;
    expect(isFake()).toBe(false);
  });
  test('에뮬레이터 + FAKE_EXTERNALS면 true', () => {
    process.env.FAKE_EXTERNALS = 'true';
    process.env.FUNCTIONS_EMULATOR = 'true';
    expect(isFake()).toBe(true);
  });
  test('에뮬레이터여도 FAKE_EXTERNALS 없으면 false', () => {
    delete process.env.FAKE_EXTERNALS;
    process.env.FUNCTIONS_EMULATOR = 'true';
    expect(isFake()).toBe(false);
  });
});

test('가짜 검색: 공백 무시 부분 일치', async () => {
  const r = await fakeKakaoSearch('찐 국밥', null);
  expect(r.map((p) => p.placeId)).toEqual(['fake-1']);
  expect((await fakeKakaoSearch('찐', null)).length).toBe(FAKE_PLACES.length);
  expect(await fakeKakaoSearch('없는가게', null)).toEqual([]);
});

test('가짜 영수증은 모든 가짜 식당에서 검증 통과', () => {
  for (const p of FAKE_PLACES) {
    expect(verifyReceipt(fakeOcr(`receipts/u1/${p.placeId}.jpg`, p, NOW), p, NOW).ok).toBe(true);
  }
});

test('가짜 영수증 승인번호는 경로마다 다르고 같은 경로면 같음', () => {
  const p = FAKE_PLACES[0];
  const a = fakeOcr('receipts/u1/a.jpg', p, NOW).approvalNo;
  expect(a).toMatch(/^\d{10}$/);
  expect(fakeOcr('receipts/u1/a.jpg', p, NOW).approvalNo).toBe(a);
  expect(fakeOcr('receipts/u1/b.jpg', p, NOW).approvalNo).not.toBe(a);
});

test('가짜 식당 지역: 5개는 성수, 1개는 베타 밖', () => {
  expect(FAKE_PLACES.map((p) => regionFor(p.address, SEED_REGIONS))).toEqual(['seongsu', 'seongsu', 'seongsu', 'seongsu', 'seongsu', null]);
});
