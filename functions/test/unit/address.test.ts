import { addressParts, regionFor } from '../../src/address';

test('지번 주소', () => {
  expect(addressParts('서울 성동구 성수동2가 300-1')).toEqual({ gu: '성동구', dong: '성수', road: null });
});
test('도로명 주소', () => {
  expect(addressParts('서울 성동구 연무장길 10')).toEqual({ gu: '성동구', dong: null, road: '연무장길' });
});
test('행정동 표기도 기본형으로', () => {
  expect(addressParts('서울시 성동구 성수2가1동 300-1').dong).toBe('성수');
});
test('regionFor: 구+동 일치 시 지역 id', () => {
  const regions = [{ id: 'seongsu', name: '성수', gu: '성동구', dongs: ['성수'] }];
  expect(regionFor('서울 성동구 성수동1가 1', regions)).toBe('seongsu');
  expect(regionFor('서울 성동구 행당동 1', regions)).toBeNull();
  expect(regionFor('서울 강남구 성수동1가 1', regions)).toBeNull();
});
