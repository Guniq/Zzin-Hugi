import { createHash } from 'node:crypto';
import { KakaoPlace, KakaoProfile, LatLng } from '../kakao';
import { OcrReceipt, PlaceInfo, kstDate } from '../receipt';

// 에뮬레이터에서만 true. 실서버에서 FAKE_EXTERNALS가 실수로 켜져도 FUNCTIONS_EMULATOR가 없으므로 false.
export const isFakeOcr = (): boolean => process.env.FAKE_EXTERNALS === 'true' && process.env.FUNCTIONS_EMULATOR === 'true';
// FAKE_KAKAO=false 면 식당 검색만 진짜 카카오로 보낸다 (영수증 인식은 계속 가짜).
export const isFakeKakao = (): boolean => isFakeOcr() && process.env.FAKE_KAKAO !== 'false';

export const FAKE_PLACES: KakaoPlace[] = [
  { placeId: 'fake-1', name: '화곡 찐국밥', address: '서울 강서구 화곡동 1011-3', roadAddress: '서울 강서구 강서로 120', category: '한식 · 국밥', lat: 37.5415, lng: 126.8405 },
  { placeId: 'fake-2', name: '화곡 찐카페', address: '서울 강서구 화곡동 1012-7', roadAddress: '서울 강서구 화곡로 301', category: '카페', lat: 37.5420, lng: 126.8410 },
  { placeId: 'fake-3', name: '화곡 찐면옥', address: '서울 강서구 화곡동 1020-1', roadAddress: '서울 강서구 곰달래로 55', category: '한식 · 냉면', lat: 37.5408, lng: 126.8395 },
  { placeId: 'fake-4', name: '화곡 찐고기', address: '서울 강서구 화곡동 1031-9', roadAddress: '서울 강서구 강서로 142', category: '한식 · 육류,고기', lat: 37.5400, lng: 126.8420 },
  { placeId: 'fake-5', name: '화곡 찐빵집', address: '서울 강서구 화곡동 1040-2', roadAddress: '서울 강서구 화곡로 288', category: '간식 · 제과,베이커리', lat: 37.5425, lng: 126.8390 },
  { placeId: 'fake-6', name: '강남 찐돈까스', address: '서울 강남구 역삼동 100', roadAddress: '서울 강남구 테헤란로 60', category: '일식 · 돈까스,우동', lat: 37.5000, lng: 127.0360 },
];

// --- 카카오 로그인 가짜: 카카오에 가지 않고 곧바로 redirectUri 로 되돌려 보낸다 (에뮬레이터 전용) ---
export function fakeAuthorizeUrl(redirectUri: string, state: string): string {
  const u = new URL(redirectUri);
  u.searchParams.set('code', 'fake-code');
  u.searchParams.set('state', state);
  return u.toString();
}
export const fakeExchange = async (code: string): Promise<string> => `fake-token:${code}`;
export const fakeKakaoMe = async (): Promise<KakaoProfile> => ({ id: 'fake-kakao-1', nickname: '카카오테스터' });

export async function fakeKakaoSearch(query: string, _near: LatLng | null): Promise<KakaoPlace[]> {
  const q = query.replace(/\s/g, '');
  return FAKE_PLACES.filter((p) => p.name.replace(/\s/g, '').includes(q));
}

export function fakeOcr(path: string, place: PlaceInfo, now: Date = new Date()): OcrReceipt {
  const approvalNo = BigInt('0x' + createHash('sha256').update(path).digest('hex').slice(0, 12)).toString().padStart(10, '0').slice(0, 10);
  return { storeName: place.name, address: place.roadAddress || place.address, date: kstDate(now), total: 12000, approvalNo };
}
