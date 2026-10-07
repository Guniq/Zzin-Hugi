export interface LatLng { lat: number; lng: number }
export interface KakaoPlace { placeId: string; name: string; address: string; roadAddress: string; lat: number; lng: number }
export interface KakaoProfile { id: string; nickname: string | null }

const FOOD_CATEGORIES = new Set(['FD6', 'CE7']);

/* eslint-disable @typescript-eslint/no-explicit-any */
export function parseKakaoKeyword(json: unknown): KakaoPlace[] {
  return ((json as any)?.documents ?? [])
    .filter((d: any) => FOOD_CATEGORIES.has(d.category_group_code))
    .map((d: any) => ({
      placeId: String(d.id),
      name: d.place_name,
      address: d.address_name ?? '',
      roadAddress: d.road_address_name ?? '',
      lat: Number(d.y),
      lng: Number(d.x),
    }));
}

export async function kakaoKeywordSearch(query: string, near: LatLng | null, restKey: string, fetchFn: typeof fetch = fetch): Promise<KakaoPlace[]> {
  const p = new URLSearchParams({ query, size: '15' });
  if (near) {
    p.set('x', String(near.lng));
    p.set('y', String(near.lat));
    p.set('radius', '20000');
  }
  const res = await fetchFn(`https://dapi.kakao.com/v2/local/search/keyword.json?${p}`, {
    headers: { Authorization: `KakaoAK ${restKey}` },
    signal: AbortSignal.timeout(5_000),
  });
  if (!res.ok) throw new Error(`kakao ${res.status}`);
  return parseKakaoKeyword(await res.json());
}

export async function kakaoMe(accessToken: string, fetchFn: typeof fetch = fetch): Promise<KakaoProfile> {
  const res = await fetchFn('https://kapi.kakao.com/v2/user/me', {
    headers: { Authorization: `Bearer ${accessToken}` },
    signal: AbortSignal.timeout(5_000),
  });
  if (!res.ok) throw new Error(`kakao_me ${res.status}`);
  const j: any = await res.json();
  return { id: String(j.id), nickname: j.kakao_account?.profile?.nickname ?? j.properties?.nickname ?? null };
}
