import { initializeApp } from 'firebase-admin/app';
import { Firestore, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { geohashForLocation } from 'geofire-common';
import { FAKE_PLACES } from './fake';
import { Region, regionFor } from '../address';
import { RestaurantSums, deriveScores } from '../scoring';
import { titleFor } from '../title';
import { crownMonths } from '../crown';

export const SEED_REGIONS: Region[] = [{ id: 'hwagok', name: '화곡', gu: '강서구', dongs: ['화곡', '화곡본'] }];

/** 데모 후기: 식당별로 [실제 별점, 이벤트 때 준 별점(없으면 null)]. fake-2·fake-4 는 이벤트 별점 5점 vs 실제 별점이 낮아 거품이 크다. */
type Stars = [number, number | null];
const SEED_USERS: { uid: string; nickname: string; likes: number; reviews: Record<string, Stars> }[] = [
  { uid: 'seed1', nickname: '찐미식가', likes: 4, reviews: { 'fake-1': [5, null], 'fake-3': [4, null], 'fake-2': [2, 5], 'fake-4': [1, 5] } },
  { uid: 'seed2', nickname: '국밥러버', likes: 2, reviews: { 'fake-1': [4, null], 'fake-3': [3, null], 'fake-2': [3, 5], 'fake-4': [1, 5] } },
  { uid: 'seed3', nickname: '동네주민', likes: 1, reviews: { 'fake-1': [3, null], 'fake-3': [4, null], 'fake-2': [1, 5], 'fake-4': [2, 5] } },
];
const TEXTS: Record<number, string> = {
  1: '리뷰 이벤트 때문에 갔는데 기대보다 많이 별로였어요',
  2: '이벤트로 갔는데 솔직히 아쉬웠어요. 다시 가진 않을 듯',
  3: '무난하게 먹기 좋았어요. 평범한 편이에요',
  4: '맛있게 먹었어요. 다음에도 갈 만해요',
  5: '다시 가고 싶은 집이에요. 강력 추천합니다',
};

type Doc = Record<string, unknown>;
export interface SeedData {
  regions: Region[];
  restaurants: Record<string, Doc>;
  reviews: Record<string, Doc>;
  users: Record<string, Doc>;
  crown: { id: string; data: Doc };
}

export function buildSeedData(now: Date): SeedData {
  const sums: Record<string, RestaurantSums> = {};
  const reviews: Record<string, Doc> = {};
  const users: Record<string, Doc> = {};
  const ts = Timestamp.fromDate(now);
  const visitDate = now.toISOString().slice(0, 10);

  for (const u of SEED_USERS) {
    let count = 0;
    for (const [placeId, [stars, eventStars]] of Object.entries(u.reviews)) {
      reviews[`${u.uid}_${placeId}`] = {
        uid: u.uid, restaurantId: placeId, region: 'hwagok', stars,
        eventJoined: eventStars !== null, eventStars, text: TEXTS[stars], photos: [],
        visitDate, likeCount: u.likes, createdAt: ts, updatedAt: ts,
      };
      const s = (sums[placeId] ??= { scoreSum: 0, reviewCount: 0, eventStarSum: 0, eventActualSum: 0, eventReviewCount: 0 });
      s.scoreSum += stars;
      s.reviewCount += 1;
      if (eventStars !== null) {
        s.eventStarSum += eventStars;
        s.eventActualSum += stars;
        s.eventReviewCount += 1;
      }
      count += 1;
    }
    const likesReceived = u.likes * count;
    users[u.uid] = {
      nickname: u.nickname, title: titleFor(likesReceived), likesReceived, verifiedReviewCount: count,
      dailyReviewCount: 0, dailyReviewDate: '', createdAt: ts,
    };
  }

  const restaurants: Record<string, Doc> = {};
  for (const p of FAKE_PLACES) {
    restaurants[p.placeId] = {
      name: p.name, address: p.address, roadAddress: p.roadAddress, category: p.category, lat: p.lat, lng: p.lng,
      geohash: geohashForLocation([p.lat, p.lng]), region: regionFor(p.address, SEED_REGIONS),
      ...(sums[p.placeId] ? { ...sums[p.placeId], ...deriveScores(sums[p.placeId]) } : {}),
    };
  }

  const { displayMonth } = crownMonths(now);
  const top = users['seed1'];
  return {
    regions: SEED_REGIONS, restaurants, reviews, users,
    crown: {
      id: `${displayMonth}_hwagok`,
      data: { uid: 'seed1', likes: top.likesReceived, region: 'hwagok', scoreMonth: displayMonth, displayMonth, status: 'confirmed' },
    },
  };
}

export async function runSeed(db: Firestore, now: Date = new Date()): Promise<void> {
  const d = buildSeedData(now);
  const batch = db.batch();
  batch.set(db.doc('config/regions'), { list: d.regions });
  for (const [id, v] of Object.entries(d.restaurants)) batch.set(db.doc(`restaurants/${id}`), v);
  for (const [id, v] of Object.entries(d.reviews)) batch.set(db.doc(`reviews/${id}`), v);
  for (const [id, v] of Object.entries(d.users)) batch.set(db.doc(`users/${id}`), v);
  batch.set(db.doc(`crowns/${d.crown.id}`), d.crown.data);
  await batch.commit();
}

// `npm run seed` — 에뮬레이터에 데모 데이터 주입
if (require.main === module) {
  process.env.FIRESTORE_EMULATOR_HOST ??= 'localhost:8080';
  initializeApp({ projectId: 'demo-zzinhugi' });
  runSeed(getFirestore()).then(() => console.log('seeded demo data →', process.env.FIRESTORE_EMULATOR_HOST));
}
