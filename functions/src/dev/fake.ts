import { createHash } from 'node:crypto';
import { KakaoPlace, LatLng } from '../kakao';
import { OcrReceipt, PlaceInfo, kstDate } from '../receipt';

// 에뮬레이터에서만 true. 실서버에서 FAKE_EXTERNALS가 실수로 켜져도 FUNCTIONS_EMULATOR가 없으므로 false.
export const isFakeOcr = (): boolean => process.env.FAKE_EXTERNALS === 'true' && process.env.FUNCTIONS_EMULATOR === 'true';
// FAKE_KAKAO=false 면 식당 검색만 진짜 카카오로 보낸다 (영수증 인식은 계속 가짜).
export const isFakeKakao = (): boolean => isFakeOcr() && process.env.FAKE_KAKAO !== 'false';

export const FAKE_PLACES: KakaoPlace[] = [
  { placeId: 'fake-1', name: '성수 찐국밥', address: '서울 성동구 성수동2가 300-1', roadAddress: '서울 성동구 연무장길 10', category: '한식 · 국밥', lat: 37.5446, lng: 127.0557 },
  { placeId: 'fake-2', name: '성수 찐카페', address: '서울 성동구 성수동1가 10', roadAddress: '서울 성동구 성수이로 20', category: '카페', lat: 37.5440, lng: 127.0560 },
  { placeId: 'fake-3', name: '성수 찐면옥', address: '서울 성동구 성수동1가 20', roadAddress: '서울 성동구 성수이로 30', category: '한식 · 냉면', lat: 37.5430, lng: 127.0570 },
  { placeId: 'fake-4', name: '성수 찐고기', address: '서울 성동구 성수동2가 31', roadAddress: '서울 성동구 아차산로 40', category: '한식 · 육류,고기', lat: 37.5420, lng: 127.0580 },
  { placeId: 'fake-5', name: '성수 찐빵집', address: '서울 성동구 성수동2가 50', roadAddress: '서울 성동구 서울숲길 50', category: '간식 · 제과,베이커리', lat: 37.5450, lng: 127.0540 },
  { placeId: 'fake-6', name: '강남 찐돈까스', address: '서울 강남구 역삼동 100', roadAddress: '서울 강남구 테헤란로 60', category: '일식 · 돈까스,우동', lat: 37.5000, lng: 127.0360 },
];

export async function fakeKakaoSearch(query: string, _near: LatLng | null): Promise<KakaoPlace[]> {
  const q = query.replace(/\s/g, '');
  return FAKE_PLACES.filter((p) => p.name.replace(/\s/g, '').includes(q));
}

export function fakeOcr(path: string, place: PlaceInfo, now: Date = new Date()): OcrReceipt {
  const approvalNo = BigInt('0x' + createHash('sha256').update(path).digest('hex').slice(0, 12)).toString().padStart(10, '0').slice(0, 10);
  return { storeName: place.name, address: place.roadAddress || place.address, date: kstDate(now), total: 12000, approvalNo };
}
