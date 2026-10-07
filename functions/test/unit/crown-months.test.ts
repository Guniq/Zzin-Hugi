import { crownMonths } from '../../src/crown';

test('10월 1일 KST 0시 → 9월 집계, 10월 표시', () => {
  expect(crownMonths(new Date('2026-09-30T15:00:00Z'))).toEqual({ scoreMonth: '2026-09', displayMonth: '2026-10' });
});
test('1월 → 전년 12월', () => {
  expect(crownMonths(new Date('2027-01-01T00:00:00Z'))).toEqual({ scoreMonth: '2026-12', displayMonth: '2027-01' });
});
