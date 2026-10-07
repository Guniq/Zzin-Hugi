import { createHash } from 'node:crypto';
import { Firestore, Timestamp, getFirestore, DocumentData } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { geohashForLocation } from 'geofire-common';
import { KakaoPlace, LatLng, kakaoKeywordSearch } from './kakao';
import { Region, regionFor } from './address';
import { REGION, KAKAO_REST_KEY } from './config';

export const CACHE_DAYS = 7;
export interface PlaceResult extends KakaoPlace { region: string | null }
export type KakaoSearch = (query: string, near: LatLng | null) => Promise<KakaoPlace[]>;

function toResult(placeId: string, d: DocumentData): PlaceResult {
  return { placeId, name: d.name, address: d.address, roadAddress: d.roadAddress, lat: d.lat, lng: d.lng, region: d.region ?? null };
}

export async function searchPlacesCore(db: Firestore, kakao: KakaoSearch, raw: unknown, now: Date): Promise<PlaceResult[]> {
  const d = (raw ?? {}) as { query?: unknown; lat?: unknown; lng?: unknown };
  const query = typeof d.query === 'string' ? d.query.trim() : '';
  if (!query || query.length > 50) throw new HttpsError('invalid-argument', 'query');
  const near: LatLng | null =
    typeof d.lat === 'number' && typeof d.lng === 'number' && Number.isFinite(d.lat) && Number.isFinite(d.lng) ? { lat: d.lat, lng: d.lng } : null;

  const key = createHash('sha256').update(`${query}|${near ? `${near.lat.toFixed(2)},${near.lng.toFixed(2)}` : ''}`).digest('hex');
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
  } catch {
    throw new HttpsError('unavailable', 'kakao_unavailable');
  }
  const regions: Region[] = (await db.doc('config/regions').get()).data()?.list ?? [];
  const results = places.map((p) => ({ ...p, region: regionFor(p.address, regions) }));

  const batch = db.batch();
  for (const r of results) {
    batch.set(
      db.doc(`restaurants/${r.placeId}`),
      { name: r.name, address: r.address, roadAddress: r.roadAddress, lat: r.lat, lng: r.lng, geohash: geohashForLocation([r.lat, r.lng]), region: r.region },
      { merge: true },
    );
  }
  batch.set(cacheRef, { placeIds: results.map((r) => r.placeId), cachedAt: Timestamp.fromDate(now) });
  await batch.commit();
  return results;
}

export const searchPlaces = onCall({ region: REGION, secrets: [KAKAO_REST_KEY] }, (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'login_required');
  return searchPlacesCore(getFirestore(), (q, near) => kakaoKeywordSearch(q, near, KAKAO_REST_KEY.value()), req.data, new Date());
});
