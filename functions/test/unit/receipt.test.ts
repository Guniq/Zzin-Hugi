import { verifyReceipt, nameMatches, addressMatches, kstDate, receiptHash, OcrReceipt, PlaceInfo } from '../../src/receipt';

const place: PlaceInfo = { name: '성수 찐국밥', address: '서울 성동구 성수동2가 300-1', roadAddress: '서울 성동구 연무장길 10' };
const NOW = new Date('2026-10-07T03:00:00Z'); // KST 2026-10-07 12:00
const ok: OcrReceipt = { storeName: '성수찐국밥', address: '서울특별시 성동구 연무장길 10 1층', date: '2026-10-06', total: 18000, approvalNo: '12345678' };

describe('nameMatches', () => {
  test('법인표기·공백 무시 + 포함 관계', () => expect(nameMatches('(주)성수 찐국밥 본점', place.name)).toBe(true));
  test('지점명 한 글자 차이', () => expect(nameMatches('스타벅스성수역점', '스타벅스 성수점')).toBe(true));
  test('다른 가게', () => expect(nameMatches('스타벅스 성수점', place.name)).toBe(false));
  test('한 글자짜리 포함은 불인정', () => expect(nameMatches('국', '국밥천국')).toBe(false));
});

describe('addressMatches', () => {
  test('도로명만 있어도 도로명 일치면 통과', () => expect(addressMatches('서울특별시 성동구 연무장길 10', place)).toBe(true));
  test('지번 동 일치', () => expect(addressMatches('서울시 성동구 성수2가1동 300-1', place)).toBe(true));
  test('구 다르면 실패', () => expect(addressMatches('서울 강남구 연무장길 10', place)).toBe(false));
  test('같은 구 다른 도로', () => expect(addressMatches('서울 성동구 왕십리로 5', place)).toBe(false));
});

describe('kstDate', () => {
  test('UTC 15:30은 KST 다음날', () => expect(kstDate(new Date('2026-10-06T15:30:00Z'))).toBe('2026-10-07'));
});

describe('verifyReceipt', () => {
  test('정상 영수증', () => {
    const r = verifyReceipt(ok, place, NOW);
    expect(r).toEqual({ ok: true, hash: receiptHash('12345678', 18000, '2026-10-06'), visitDate: '2026-10-06' });
    if (r.ok) expect(r.hash).toMatch(/^[0-9a-f]{64}$/);
  });
  test('필수 필드 누락 → unreadable', () => {
    expect(verifyReceipt({ ...ok, approvalNo: null }, place, NOW)).toEqual({ ok: false, reason: 'unreadable' });
    expect(verifyReceipt({ ...ok, address: null }, place, NOW)).toEqual({ ok: false, reason: 'unreadable' });
  });
  test('다른 가게 → store_mismatch', () => {
    expect(verifyReceipt({ ...ok, storeName: '스타벅스 성수점' }, place, NOW)).toEqual({ ok: false, reason: 'store_mismatch' });
  });
  test('정확히 30일 전은 통과', () => expect(verifyReceipt({ ...ok, date: '2026-09-07' }, place, NOW).ok).toBe(true));
  test('31일 전은 거절', () => {
    expect(verifyReceipt({ ...ok, date: '2026-09-06' }, place, NOW)).toEqual({ ok: false, reason: 'date_expired' });
  });
  test('미래 날짜는 거절', () => {
    expect(verifyReceipt({ ...ok, date: '2026-10-08' }, place, NOW)).toEqual({ ok: false, reason: 'date_expired' });
  });
  test('해시는 금액이 다르면 달라짐', () => {
    expect(receiptHash('1', 100, '2026-10-06')).not.toBe(receiptHash('1', 101, '2026-10-06'));
  });
});
