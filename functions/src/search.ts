import { createHash } from 'node:crypto';
import { Firestore, Timestamp, getFirestore, DocumentData } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { geohashForLocation } from 'geofire-common';
import { KakaoPlace, LatLng, kakaoKeywordSearch } from './kakao';
import { Region, regionFor } from './address';
import { REGION, KAKAO_REST_KEY } from './config';
import { isFakeKakao, fakeKakaoSearch } from './dev/fake';

export const CACHE_DAYS = 7;
// 위치를 못 받았을 때 검색 기준점: 베타 지역(화곡동, 화곡역 인근) 중심.
// ponytail: 베타 지역이 늘면 config/regions 에 center 를 넣고 가장 가까운 지역을 쓴다.
export const DEFAULT_NEAR: LatLng = { lat: 37.5412, lng: 126.8402 };
/** realScore·reviewCount: 이미 찐후기가 쌓인 식당이면 지도 핀에 점수를 보여 주기 위한 값 */
export interface PlaceResult extends KakaoPlace { region: string | null; realScore: number | null; reviewCount: number }
export type KakaoSearch = (query: string, near: LatLng | null) => Promise<KakaoPlace[]>;

function toResult(placeId: string, d: DocumentData): PlaceResult {
  return {
    placeId, name: d.name, address: d.address, roadAddress: d.roadAddress, category: d.category ?? '', lat: d.lat, lng: d.lng,
    region: d.region ?? null, realScore: d.realScore ?? null, reviewCount: d.reviewCount ?? 0,
  };
}

export async function searchPlacesCore(db: Firestore, kakao: KakaoSearch, raw: unknown, now: Date): Promise<PlaceResult[]> {
  const d = (raw ?? {}) as { query?: unknown; lat?: unknown; lng?: unknown };
  const query = typeof d.query === 'string' ? d.query.trim() : '';
  if (!query || query.length > 50) throw new HttpsError('invalid-argument', 'query');
  const near: LatLng =
    typeof d.lat === 'number' && typeof d.lng === 'number' && Number.isFinite(d.lat) && Number.isFinite(d.lng) ? { lat: d.lat, lng: d.lng } : DEFAULT_NEAR;

  const key = createHash('sha256').update(`${query}|${near.lat.toFixed(3)},${near.lng.toFixed(3)}`).digest('hex');
  const cacheRef = db.doc(`searchCache/${key}`);
  const cached = (await cacheRef.get()).data();
  if (cached && now.getTime() - cached.cachedAt.toMillis() < CACHE_DAYS * 86_400_000) {
    const ids: string[] = cached.placeIds;
    if (!ids.length) return [];
    const snaps = await db.getAll(...ids.map((id) => db.doc(`restaurants/${id}`)));
    return snaps.filter((s) => s.exists).map((s) => toResult(s.id, s.data()!));
  }

  let places: KakaoPlace[];
  try {
    places = await kakao(query, near);
  } catch (e) {
    // 앱에는 일반 문구만 보이고, 원인(상태 코드·카카오 메시지)은 서버 로그에만 남긴다.
    logger.error('kakao search failed', { error: e instanceof Error ? e.message : String(e) });
    throw new HttpsError('unavailable', 'kakao_unavailable');
  }
  const regions: Region[] = (await db.doc('config/regions').get()).data()?.list ?? [];
  // 이미 후기가 있는 식당의 점수를 붙인다 (merge 저장이라 아래 batch 가 점수를 지우지 않는다).
  const existing = places.length ? await db.getAll(...places.map((p) => db.doc(`restaurants/${p.placeId}`))) : [];
  const results: PlaceResult[] = places.map((p, i) => ({
    ...p,
    region: regionFor(p.address, regions),
    realScore: existing[i]?.data()?.realScore ?? null,
    reviewCount: existing[i]?.data()?.reviewCount ?? 0,
  }));

  const batch = db.batch();
  for (const r of results) {
    batch.set(
      db.doc(`restaurants/${r.placeId}`),
      { name: r.name, address: r.address, roadAddress: r.roadAddress, category: r.category, lat: r.lat, lng: r.lng, geohash: geohashForLocation([r.lat, r.lng]), region: r.region },
      { merge: true },
    );
  }
  batch.set(cacheRef, { placeIds: results.map((r) => r.placeId), cachedAt: Timestamp.fromDate(now) });
  await batch.commit();
  return results;
}

export const searchPlaces = onCall({ region: REGION, secrets: [KAKAO_REST_KEY] }, (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'login_required');
  const kakao: KakaoSearch = isFakeKakao() ? fakeKakaoSearch : (q, near) => kakaoKeywordSearch(q, near, KAKAO_REST_KEY.value());
  return searchPlacesCore(getFirestore(), kakao, req.data, new Date());
});
