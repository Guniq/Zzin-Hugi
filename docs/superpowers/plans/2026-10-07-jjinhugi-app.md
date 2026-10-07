# 찐후기 Flutter 앱 (플랜 2/3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로컬 Firebase Emulator에 붙어서 Chrome에서 끝까지 돌려볼 수 있는 찐후기 앱(로그인 → 목록 → 상세 → 후기 작성 → 따봉·신고 → 프로필)을 만든다. 카카오 키·CLOVA 키 없이도 전체 흐름을 테스트할 수 있다.

**Architecture:** Flutter(웹+모바일 공용 코드). 화면은 `Backend` 인터페이스 하나만 보고, 실제 구현(`FirebaseBackend`)과 테스트용 가짜(`FakeBackend`)를 Riverpod `Provider`로 갈아끼운다. 순수 로직(점수 표기, 이진 비교 순위 결정, 오류 문구, 모델 파싱)은 Flutter 의존 없이 단위 테스트한다. 백엔드(플랜 1)는 에뮬레이터 개발 모드에서만 카카오 검색·OCR을 가짜로 대체한다(`FAKE_EXTERNALS`).

**Tech Stack:** Flutter(stable, Dart 3), flutter_riverpod, go_router, firebase_core/auth/cloud_firestore/cloud_functions/firebase_storage, image_picker, uuid. 백엔드 쪽은 플랜 1과 동일(TypeScript, Jest, Emulator).

**Spec:** `docs/superpowers/specs/2026-10-07-jjinhugi-design.md`
**선행 플랜:** `docs/superpowers/plans/2026-10-07-jjinhugi-backend.md` (완료, `feat/backend` 브랜치). 함수 계약은 그 문서 끝 "앱 계약" 절.

## 이 플랜의 범위 (스펙 대비 조정)

| 스펙 항목 | 이 플랜 | 이유 |
|---|---|---|
| 카카오·Apple 로그인 | **제외 → 플랜 3** | 카카오 네이티브 키, Apple 개발자 계정, 실기기 필요. 에뮬레이터용 테스트 로그인으로 대체 |
| 지도 | **제외 → 플랜 3** | 네이버 지도 SDK는 웹 미지원, 클라이언트 ID 필요. 목록 화면으로 대체 |
| 실제 Firebase 프로젝트 연결 | **제외 → 플랜 3** | 프로젝트·`firebase_options.dart` 필요 |
| 작성 중 후기 로컬 임시저장 | **제외** | 화면이 열려 있는 동안은 입력 유지. 앱 종료 후 복원은 v2 |
| 사진 표시 | 포함 | `getDownloadURL` 사용 |

## Global Constraints

- 앱 폴더: `app/`, 프로젝트명 `jjinhugi`, org `kr.co.jjinhugi`
- 모든 화면 문구는 한국어
- Functions 리전 `asia-northeast3` (`functionsRegion`), Emulator 프로젝트 ID `demo-jjinhugi`
- 에뮬레이터 모드는 `--dart-define=USE_EMULATOR=true`일 때만. 이 값이 없으면 앱은 시작 시 예외를 던진다(실 프로젝트는 플랜 3)
- 베타 지역은 앱에 상수로 고정: `[성수(seongsu)]` (`config/regions`는 클라이언트가 읽을 수 없음)
- 점수 구간·공식은 백엔드와 동일: 최고 7~10 / 괜찮 4~7 / 별로 0~4, 소수점 1자리
- 한줄평 10~300자, 사진 최대 5장, 후기 별점 1~5
- 실제 키·시크릿은 어떤 파일에도 쓰지 않는다 (`.env.local`, `.secret.local`은 가짜 값이며 git 무시)

## Review Focus

1. **같은 식당 재방문 시 비교 후보에 자기 자신이 들어가면 안 됨** → Task 7 `후보에서 현재 식당 제외` 테스트
2. **인증 후기가 0개인 유저의 따봉** → 규칙이 거부하므로 UI가 미리 안내해야 함 → Task 6 `인증 후기 없으면 따봉 안내` 테스트
3. **본인 후기에는 따봉 버튼이 비활성** → Task 6 `본인 후기 따봉 비활성` 테스트
4. **제출 실패(영수증 불일치 등) 시 입력이 사라지면 안 되고 이유가 보여야 함** → Task 7 `제출 실패 시 입력 보존` 테스트
5. **점수 null(데이터 부족)과 베타 지역 밖 식당** → Task 5 `데이터 부족 표시`, Task 7 `베타 지역 밖 식당 선택 불가` 테스트

---

## 파일 구조

```
functions/                          (플랜 1 코드에 추가)
  scripts/dev-setup.js              에뮬레이터용 가짜 .env/.secret 생성
  src/dev/fake.ts                   가짜 카카오 검색·OCR, isFake()
  src/dev/seed.ts                   데모 데이터 생성·주입
  test/unit/fake.test.ts, seed.test.ts
  test/emu/seed.test.ts
app/
  pubspec.yaml
  lib/
    main.dart                       Firebase 초기화 → 앱 실행
    app.dart                        MaterialApp.router, 테마
    router.dart                     go_router + 로그인 리다이렉트
    core/env.dart                   dart-define 상수
    core/firebase_setup.dart        Firebase 초기화, 에뮬레이터 연결
    core/regions.dart               베타 지역 상수
    core/time.dart                  KST 월 계산
    domain/score.dart               Tier, 개인 점수, 점수 표기, 거품 단계
    domain/ranking_session.dart     이진 비교 순위 결정
    domain/errors.dart              함수 오류 → 한국어 문구
    domain/models.dart              Restaurant, Review, AppUser, Crown, PlaceResult, SubmitInput, 정렬 enum
    data/backend.dart               Backend 인터페이스 + FirebaseBackend
    data/auth_service.dart          AuthService 인터페이스 + FirebaseAuthService(테스트 로그인)
    data/providers.dart             Riverpod providers
    features/login/login_screen.dart
    features/home/home_screen.dart, restaurant_card.dart
    features/restaurant/restaurant_screen.dart, review_card.dart
    features/write/write_review_screen.dart
    features/profile/profile_screen.dart
  test/
    helpers.dart                    FakeBackend, FakeAuth, harness()
    domain/*.test.dart              순수 로직 테스트
    features/*_test.dart            위젯 테스트
docs/run-local.md                   로컬 실행·수동 점검 가이드
```

---

### Task 0: 백엔드 개발 모드 (가짜 외부 API + 시드 데이터)

키 없이 앱 전체를 돌리기 위한 백엔드 보강. **에뮬레이터에서만** 켜지고 실서버에서는 절대 켜지지 않는다.

**Files:**
- Create: `functions/src/dev/fake.ts`, `functions/src/dev/seed.ts`, `functions/scripts/dev-setup.js`
- Modify: `functions/src/search.ts`, `functions/src/review.ts`, `functions/package.json`, `.gitignore`
- Test: `functions/test/unit/fake.test.ts`, `functions/test/unit/seed.test.ts`, `functions/test/emu/seed.test.ts`

**Interfaces:**
- Consumes: `KakaoPlace`, `LatLng` (kakao.ts) / `OcrReceipt`, `PlaceInfo`, `kstDate`, `verifyReceipt` (receipt.ts) / `regionFor`, `Region` (address.ts) / `deriveScores`, `personalScore`, `round1`, `TIERS`, `Tier` (scoring.ts) / `titleFor` (title.ts) / `crownMonths` (crown.ts)
- Produces:
  - `isFake(): boolean` — `FAKE_EXTERNALS === 'true'` **그리고** `FUNCTIONS_EMULATOR === 'true'`일 때만 true
  - `FAKE_PLACES: KakaoPlace[]` (6개: `fake-1`~`fake-5` 성수, `fake-6` 강남)
  - `fakeKakaoSearch(query: string, near: LatLng | null): Promise<KakaoPlace[]>` — 공백 무시 부분 일치
  - `fakeOcr(path: string, place: PlaceInfo, now?: Date): OcrReceipt` — 해당 식당의 정상 영수증, 승인번호는 경로 해시(경로가 다르면 다름)
  - `SEED_REGIONS: Region[]`, `buildSeedData(now: Date): SeedData`, `runSeed(db: Firestore, now?: Date): Promise<void>`
  - `SubmitDeps.ocr` 시그니처가 `(receiptPath: string, place: PlaceInfo) => Promise<OcrReceipt>`로 확장 (기존 테스트는 인자를 덜 받는 함수라 그대로 호환)

- [ ] **Step 1: 실패하는 테스트 작성**

`functions/test/unit/fake.test.ts`:
```ts
import { isFake, fakeKakaoSearch, fakeOcr, FAKE_PLACES } from '../../src/dev/fake';
import { verifyReceipt } from '../../src/receipt';
import { regionFor } from '../../src/address';
import { SEED_REGIONS } from '../../src/dev/seed';

const NOW = new Date('2026-10-07T03:00:00Z');

describe('isFake', () => {
  const saved = { f: process.env.FAKE_EXTERNALS, e: process.env.FUNCTIONS_EMULATOR };
  afterEach(() => {
    process.env.FAKE_EXTERNALS = saved.f;
    process.env.FUNCTIONS_EMULATOR = saved.e;
    if (saved.f === undefined) delete process.env.FAKE_EXTERNALS;
    if (saved.e === undefined) delete process.env.FUNCTIONS_EMULATOR;
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
```

`functions/test/unit/seed.test.ts`:
```ts
import { buildSeedData } from '../../src/dev/seed';

const NOW = new Date('2026-10-07T03:00:00Z');
const d = buildSeedData(NOW);

test('찐점수·거품지수 계산 결과', () => {
  expect(d.restaurants['fake-1']).toMatchObject({ reviewCount: 3, realScore: 7.8, eventScore: null, bubble: null });
  expect(d.restaurants['fake-3']).toMatchObject({ reviewCount: 3, realScore: 7.5 });
  expect(d.restaurants['fake-2']).toMatchObject({ realScore: 3.8, eventScore: 10, bubble: 6.2 });
  expect(d.restaurants['fake-4']).toMatchObject({ realScore: 2.3, eventScore: 10, bubble: 7.7 });
});

test('후기 없는 식당은 점수 필드가 없음 (홈 목록에서 제외됨)', () => {
  expect(d.restaurants['fake-5']).not.toHaveProperty('realScore');
  expect(d.restaurants['fake-5']).toMatchObject({ region: 'seongsu' });
  expect(d.restaurants['fake-6']).toMatchObject({ region: null });
});

test('후기·유저·대마왕', () => {
  expect(Object.keys(d.reviews)).toHaveLength(12);
  expect(d.reviews['seed1_fake-1']).toMatchObject({ tier: 'best', personalScore: 9.3, likeCount: 4, eventJoined: false });
  expect(d.reviews['seed1_fake-4']).toMatchObject({ tier: 'bad', eventJoined: true, eventStars: 5 });
  expect(d.users['seed1']).toMatchObject({ nickname: '찐미식가', verifiedReviewCount: 4, likesReceived: 16, title: '찐후기러' });
  expect(d.users['seed3']).toMatchObject({ likesReceived: 4, title: '찐린이' });
  expect(d.crown).toMatchObject({ id: '2026-10_seongsu', data: { uid: 'seed1', status: 'confirmed', region: 'seongsu' } });
});
```

`functions/test/emu/seed.test.ts`:
```ts
import { testDb, clearFirestore } from './helpers';
import { runSeed } from '../../src/dev/seed';

const db = testDb();
const NOW = new Date('2026-10-07T03:00:00Z');

beforeEach(async () => {
  await clearFirestore();
  await runSeed(db, NOW);
});

test('앱 홈 쿼리: 찐점수 높은 순, 후기 없는 식당 제외', async () => {
  const snap = await db.collection('restaurants').where('region', '==', 'seongsu').orderBy('realScore', 'desc').get();
  expect(snap.docs.map((x) => x.id)).toEqual(['fake-1', 'fake-3', 'fake-2', 'fake-4']);
});

test('앱 홈 쿼리: 거품 큰 순', async () => {
  const snap = await db.collection('restaurants').where('region', '==', 'seongsu').orderBy('bubble', 'desc').get();
  expect(snap.docs.slice(0, 2).map((x) => x.id)).toEqual(['fake-4', 'fake-2']);
});

test('상세 후기 쿼리: 따봉순', async () => {
  const snap = await db.collection('reviews').where('restaurantId', '==', 'fake-4').orderBy('likeCount', 'desc').get();
  expect(snap.docs.map((x) => x.data().uid)).toEqual(['seed1', 'seed2', 'seed3']);
});

test('대마왕·지역 문서', async () => {
  expect((await db.doc('crowns/2026-10_seongsu').get()).data()).toMatchObject({ uid: 'seed1', status: 'confirmed' });
  expect((await db.doc('config/regions').get()).data()!.list[0]).toMatchObject({ id: 'seongsu' });
});
```

- [ ] **Step 2: 실패 확인**

Run: `npm --prefix functions run test:unit`
Expected: FAIL — `Cannot find module '../../src/dev/fake'`

- [ ] **Step 3: `fake.ts` 구현**

`functions/src/dev/fake.ts`:
```ts
import { createHash } from 'node:crypto';
import { KakaoPlace, LatLng } from '../kakao';
import { OcrReceipt, PlaceInfo, kstDate } from '../receipt';

// 에뮬레이터에서만 true. 실서버에서 FAKE_EXTERNALS가 실수로 켜져도 FUNCTIONS_EMULATOR가 없으므로 false.
export const isFake = (): boolean => process.env.FAKE_EXTERNALS === 'true' && process.env.FUNCTIONS_EMULATOR === 'true';

export const FAKE_PLACES: KakaoPlace[] = [
  { placeId: 'fake-1', name: '성수 찐국밥', address: '서울 성동구 성수동2가 300-1', roadAddress: '서울 성동구 연무장길 10', lat: 37.5446, lng: 127.0557 },
  { placeId: 'fake-2', name: '성수 찐카페', address: '서울 성동구 성수동1가 10', roadAddress: '서울 성동구 성수이로 20', lat: 37.5440, lng: 127.0560 },
  { placeId: 'fake-3', name: '성수 찐면옥', address: '서울 성동구 성수동1가 20', roadAddress: '서울 성동구 성수이로 30', lat: 37.5430, lng: 127.0570 },
  { placeId: 'fake-4', name: '성수 찐고기', address: '서울 성동구 성수동2가 31', roadAddress: '서울 성동구 아차산로 40', lat: 37.5420, lng: 127.0580 },
  { placeId: 'fake-5', name: '성수 찐빵집', address: '서울 성동구 성수동2가 50', roadAddress: '서울 성동구 서울숲길 50', lat: 37.5450, lng: 127.0540 },
  { placeId: 'fake-6', name: '강남 찐돈까스', address: '서울 강남구 역삼동 100', roadAddress: '서울 강남구 테헤란로 60', lat: 37.5000, lng: 127.0360 },
];

export async function fakeKakaoSearch(query: string, _near: LatLng | null): Promise<KakaoPlace[]> {
  const q = query.replace(/\s/g, '');
  return FAKE_PLACES.filter((p) => p.name.replace(/\s/g, '').includes(q));
}

export function fakeOcr(path: string, place: PlaceInfo, now: Date = new Date()): OcrReceipt {
  const approvalNo = BigInt('0x' + createHash('sha256').update(path).digest('hex').slice(0, 12)).toString().padStart(10, '0').slice(0, 10);
  return { storeName: place.name, address: place.roadAddress || place.address, date: kstDate(now), total: 12000, approvalNo };
}
```

- [ ] **Step 4: `seed.ts` 구현**

`functions/src/dev/seed.ts`:
```ts
import { initializeApp } from 'firebase-admin/app';
import { Firestore, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { geohashForLocation } from 'geofire-common';
import { FAKE_PLACES } from './fake';
import { Region, regionFor } from '../address';
import { TIERS, Tier, deriveScores, personalScore, round1 } from '../scoring';
import { titleFor } from '../title';
import { crownMonths } from '../crown';

export const SEED_REGIONS: Region[] = [{ id: 'seongsu', name: '성수', gu: '성동구', dongs: ['성수'] }];

const SEED_USERS: { uid: string; nickname: string; likes: number; ranking: Record<Tier, string[]> }[] = [
  { uid: 'seed1', nickname: '찐미식가', likes: 4, ranking: { best: ['fake-1', 'fake-3'], ok: ['fake-2'], bad: ['fake-4'] } },
  { uid: 'seed2', nickname: '국밥러버', likes: 2, ranking: { best: ['fake-1'], ok: ['fake-3', 'fake-2'], bad: ['fake-4'] } },
  { uid: 'seed3', nickname: '동네주민', likes: 1, ranking: { best: ['fake-3'], ok: ['fake-1'], bad: ['fake-4', 'fake-2'] } },
];
// 리뷰 이벤트로 별점 5점을 준 식당 (거품지수가 크게 나오는 데모)
const EVENT_STARS: Record<string, number> = { 'fake-2': 5, 'fake-4': 5 };
const TEXTS: Record<Tier, string> = {
  best: '다시 가고 싶은 집이에요. 강력 추천합니다',
  ok: '무난하게 먹기 좋았어요. 평범한 편이에요',
  bad: '리뷰 이벤트 때문에 갔는데 기대보다 별로였어요',
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
  const sums: Record<string, { scoreSum: number; reviewCount: number; eventStarSum: number; eventReviewCount: number }> = {};
  const reviews: Record<string, Doc> = {};
  const users: Record<string, Doc> = {};
  const ts = Timestamp.fromDate(now);
  const visitDate = now.toISOString().slice(0, 10);

  for (const u of SEED_USERS) {
    let count = 0;
    for (const tier of TIERS) {
      u.ranking[tier].forEach((placeId, i) => {
        const score = personalScore(tier, i, u.ranking[tier].length);
        const stars = EVENT_STARS[placeId] ?? null;
        reviews[`${u.uid}_${placeId}`] = {
          uid: u.uid, restaurantId: placeId, region: 'seongsu', tier, personalScore: score,
          eventJoined: stars !== null, eventStars: stars, text: TEXTS[tier], photos: [],
          visitDate, likeCount: u.likes, createdAt: ts, updatedAt: ts,
        };
        const s = (sums[placeId] ??= { scoreSum: 0, reviewCount: 0, eventStarSum: 0, eventReviewCount: 0 });
        s.scoreSum = round1(s.scoreSum + score);
        s.reviewCount += 1;
        if (stars !== null) { s.eventStarSum += stars; s.eventReviewCount += 1; }
        count += 1;
      });
    }
    const likesReceived = u.likes * count;
    users[u.uid] = {
      nickname: u.nickname, title: titleFor(likesReceived), likesReceived, verifiedReviewCount: count,
      ranking: u.ranking, dailyReviewCount: 0, dailyReviewDate: '', createdAt: ts,
    };
  }

  const restaurants: Record<string, Doc> = {};
  for (const p of FAKE_PLACES) {
    restaurants[p.placeId] = {
      name: p.name, address: p.address, roadAddress: p.roadAddress, lat: p.lat, lng: p.lng,
      geohash: geohashForLocation([p.lat, p.lng]), region: regionFor(p.address, SEED_REGIONS),
      ...(sums[p.placeId] ? { ...sums[p.placeId], ...deriveScores(sums[p.placeId]) } : {}),
    };
  }

  const { displayMonth } = crownMonths(now);
  const top = users['seed1'];
  return {
    regions: SEED_REGIONS, restaurants, reviews, users,
    crown: {
      id: `${displayMonth}_seongsu`,
      data: { uid: 'seed1', likes: top.likesReceived, region: 'seongsu', scoreMonth: displayMonth, displayMonth, status: 'confirmed' },
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
  initializeApp({ projectId: 'demo-jjinhugi' });
  runSeed(getFirestore()).then(() => console.log('seeded demo data →', process.env.FIRESTORE_EMULATOR_HOST));
}
```

- [ ] **Step 5: 통과 확인**

Run: `npm --prefix functions run test:unit && npm --prefix functions run test:emu`
Expected: PASS (fake 8 + seed 3 단위 테스트, seed 4 에뮬레이터 테스트 추가). 기존 테스트도 모두 통과.

> 숫자가 어긋나면 **테스트 값을 고치지 말고** 먼저 `buildSeedData` 계산을 의심한다. 기대값은 `personalScore`/`deriveScores` 공식으로 손계산한 값이다 (예: fake-4 찐 2.3 = (2+2+3)/3, 이벤트 10, 거품 7.7).

- [ ] **Step 6: 콜러블에 가짜 연결**

`functions/src/search.ts` — import와 콜러블 수정:
```ts
import { isFake, fakeKakaoSearch } from './dev/fake';
```
```ts
export const searchPlaces = onCall({ region: REGION, secrets: [KAKAO_REST_KEY] }, (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'login_required');
  const kakao: KakaoSearch = isFake() ? fakeKakaoSearch : (q, near) => kakaoKeywordSearch(q, near, KAKAO_REST_KEY.value());
  return searchPlacesCore(getFirestore(), kakao, req.data, new Date());
});
```

`functions/src/review.ts` — import 추가, `SubmitDeps` 시그니처 확장, 코어 호출부, 콜러블 수정:
```ts
import { isFake, fakeOcr } from './dev/fake';
```
```ts
export interface SubmitDeps { ocr: (receiptPath: string, place: PlaceInfo) => Promise<OcrReceipt> }
```
코어 안의 OCR 호출을 다음으로 교체:
```ts
    ocr = await deps.ocr(input.receiptPath, place as PlaceInfo);
```
콜러블의 `const ocr = ...` 블록을 다음으로 교체:
```ts
  const ocr = isFake()
    ? async (path: string, place: PlaceInfo) => fakeOcr(path, place)
    : async (path: string) => {
        const [buf] = await getStorage().bucket().file(path).download();
        return clovaOcr(buf, { url: CLOVA_OCR_URL.value(), secret: CLOVA_OCR_SECRET.value() });
      };
```

- [ ] **Step 7: 개발 설정 스크립트와 npm 스크립트**

`functions/scripts/dev-setup.js`:
```js
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
fs.writeFileSync(path.join(root, '.env.local'), 'FAKE_EXTERNALS=true\nCLOVA_OCR_URL=http://fake.local\n');
fs.writeFileSync(path.join(root, '.secret.local'), 'KAKAO_REST_KEY=fake\nCLOVA_OCR_SECRET=fake\n');
console.log('wrote functions/.env.local and functions/.secret.local (에뮬레이터 전용, 가짜 값)');
```

`functions/package.json`의 `scripts`에 추가:
```json
    "dev:setup": "node scripts/dev-setup.js",
    "emu": "cd .. && npx --prefix functions firebase emulators:start --project demo-jjinhugi --only auth,functions,firestore,storage",
    "seed": "node lib/dev/seed.js"
```

`.gitignore`에 추가:
```
functions/.env.local
functions/.secret.local
```

- [ ] **Step 8: 전체 검증**

Run: `npm --prefix functions run build && npm --prefix functions run test:unit && npm --prefix functions run test:emu`
Expected: `tsc` 에러 없음, 모든 테스트 통과(기존 + 신규)

- [ ] **Step 9: 커밋**

```bash
git add functions .gitignore
git commit -m "feat(functions): add emulator-only fake externals and demo seed data"
```

---

### Task 1: 환경 준비 + Flutter 프로젝트 골격

**Files:**
- Create: `app/` (flutter create 산출물), `app/lib/main.dart`, `app/lib/app.dart`, `app/lib/core/env.dart`, `app/lib/core/firebase_setup.dart`, `app/lib/core/regions.dart`
- Delete: `app/test/widget_test.dart`

**Interfaces:**
- Produces:
  - `const bool useEmulator`, `const String emulatorHost`, `const String functionsRegion = 'asia-northeast3'` (env.dart)
  - `Future<void> initFirebase()` (firebase_setup.dart) — 에뮬레이터 모드가 아니면 `UnsupportedError`
  - `class BetaRegion { final String id; final String name; }`, `const List<BetaRegion> betaRegions` (regions.dart)
  - `class JjinApp extends ConsumerWidget` (app.dart) — `routerProvider`(Task 3)를 사용

- [ ] **Step 1: Flutter SDK 설치 확인 (사람 또는 실행자, 1회)**

이 PC에는 Flutter가 없다. 설치되어 있지 않으면:
```powershell
git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter
[Environment]::SetEnvironmentVariable('Path', $env:Path + ';C:\src\flutter\bin', 'User')
# 새 터미널을 열고
flutter doctor
```
Expected: `Flutter`, `Chrome`이 ✓. Android toolchain·Visual Studio는 ✗여도 웹 테스트에는 무관.

- [ ] **Step 2: 프로젝트 생성과 의존성**

Run (저장소 루트):
```bash
flutter create --org kr.co.jjinhugi --project-name jjinhugi --platforms web,android,ios app
cd app
flutter pub add flutter_riverpod go_router firebase_core firebase_auth cloud_firestore cloud_functions firebase_storage image_picker uuid
rm test/widget_test.dart
```
Expected: `pubspec.yaml`에 의존성 추가, 에러 없음

- [ ] **Step 3: 파일 작성**

`app/lib/core/env.dart`:
```dart
/// `flutter run --dart-define=USE_EMULATOR=true` 일 때만 true.
const bool useEmulator = bool.fromEnvironment('USE_EMULATOR');
const String emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');
const String functionsRegion = 'asia-northeast3';
```

`app/lib/core/regions.dart`:
```dart
class BetaRegion {
  const BetaRegion(this.id, this.name);
  final String id;
  final String name;
}

// config/regions 는 클라이언트가 읽을 수 없어서 앱에 고정. 지역을 늘릴 땐 둘 다 수정.
const List<BetaRegion> betaRegions = [BetaRegion('seongsu', '성수')];
```

`app/lib/core/firebase_setup.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'env.dart';

const _demoOptions = FirebaseOptions(
  apiKey: 'demo-key',
  appId: '1:1:web:demo',
  messagingSenderId: '1',
  projectId: 'demo-jjinhugi',
  storageBucket: 'demo-jjinhugi.appspot.com',
);

Future<void> initFirebase() async {
  if (!useEmulator) {
    throw UnsupportedError('실제 Firebase 프로젝트 연결은 플랜 3에서 추가됩니다. --dart-define=USE_EMULATOR=true 로 실행하세요.');
  }
  await Firebase.initializeApp(options: _demoOptions);
  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
  await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
  FirebaseFunctions.instanceFor(region: functionsRegion).useFunctionsEmulator(emulatorHost, 5001);
}
```

`app/lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  runApp(const ProviderScope(child: JjinApp()));
}
```

`app/lib/app.dart` (Task 3의 `router.dart`가 생기기 전까지는 컴파일되지 않으므로, 이 단계에서는 임시로 `routerProvider` import를 Task 3에서 추가한다. 지금은 아래 임시 버전을 쓴다):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class JjinApp extends ConsumerWidget {
  const JjinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '찐후기',
      theme: ThemeData(colorSchemeSeed: const Color(0xFFE8590C), useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('찐후기'))),
    );
  }
}
```

- [ ] **Step 4: 분석 통과 확인**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add app
git commit -m "feat(app): scaffold Flutter project with emulator Firebase setup"
```

---

### Task 2: 순수 로직 (점수·순위 결정·오류 문구·모델)

**Files:**
- Create: `app/lib/core/time.dart`, `app/lib/domain/score.dart`, `app/lib/domain/ranking_session.dart`, `app/lib/domain/errors.dart`, `app/lib/domain/models.dart`
- Test: `app/test/domain/score_test.dart`, `app/test/domain/ranking_session_test.dart`, `app/test/domain/errors_test.dart`, `app/test/domain/models_test.dart`, `app/test/domain/time_test.dart`

**Interfaces:**
- Produces:
  - `enum Tier { best, ok, bad }` + `extension TierX on Tier { String get label }` — `최고 / 괜찮 / 별로`
  - `double round1(double)`, `double personalScore(Tier tier, int index, int n)` — 백엔드와 동일 공식
  - `String scoreText(double?)` — null이면 `데이터 부족`, 아니면 소수 1자리
  - `String bubbleText(double?)` — null이면 `-`, 양수는 `+` 접두
  - `enum BubbleLevel { unknown, low, mid, high }`, `BubbleLevel bubbleLevel(double?)` — `<1` low, `<2.5` mid, 그 이상 high
  - `class RankingSession { RankingSession(List<String> candidates); bool get done; String? get current; int get index; void answer({required bool newIsBetter}); }`
  - `String reviewErrorText(String? message)`
  - `String kstMonth(DateTime now)` — `yyyy-MM`
  - 모델: `PlaceResult`, `Restaurant`, `Review`, `AppUser`, `Crown`, `SubmitInput`, `enum RestaurantSort { real, bubble }`, `enum ReviewSort { likes, recent }`
    - `PlaceResult(placeId, name, address, region?)` / `PlaceResult.fromMap(Map<String, dynamic>)`
    - `Restaurant(id, name, address, region?, realScore?, eventScore?, bubble?, reviewCount, eventReviewCount)` / `Restaurant.fromMap(String id, Map<String, dynamic>)` / `PlaceResult toPlace()`
    - `Review(id, uid, restaurantId, tier, personalScore, eventJoined, eventStars?, text, photos, visitDate, likeCount, createdAt?)` / `Review.fromMap(String id, Map<String, dynamic>)`
    - `AppUser(uid, nickname, title, likesReceived, verifiedReviewCount, ranking: Map<Tier, List<String>>)` / `AppUser.fromMap(String uid, Map<String, dynamic>)`
    - `Crown(uid, likes, status)` / `Crown.fromMap(Map<String, dynamic>)`
    - `SubmitInput({placeId, receiptPath, tier, rankIndex, eventJoined, eventStars?, text, photos})` / `Map<String, dynamic> toMap()`

- [ ] **Step 1: 실패하는 테스트 작성**

`app/test/domain/score_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jjinhugi/domain/score.dart';

void main() {
  group('personalScore (백엔드와 같은 값)', () {
    test('혼자면 구간 중앙', () {
      expect(personalScore(Tier.best, 0, 1), 8.5);
      expect(personalScore(Tier.ok, 0, 1), 5.5);
      expect(personalScore(Tier.bad, 0, 1), 2.0);
    });
    test('둘이면 위아래로 나뉨', () {
      expect(personalScore(Tier.best, 0, 2), 9.3);
      expect(personalScore(Tier.best, 1, 2), 7.8);
    });
  });

  test('scoreText: null은 데이터 부족', () {
    expect(scoreText(null), '데이터 부족');
    expect(scoreText(7.8), '7.8');
    expect(scoreText(8), '8.0');
  });

  test('bubbleText', () {
    expect(bubbleText(null), '-');
    expect(bubbleText(7.7), '+7.7');
    expect(bubbleText(0), '+0.0');
    expect(bubbleText(-1.2), '-1.2');
  });

  test('bubbleLevel 경계', () {
    expect(bubbleLevel(null), BubbleLevel.unknown);
    expect(bubbleLevel(0.9), BubbleLevel.low);
    expect(bubbleLevel(1.0), BubbleLevel.mid);
    expect(bubbleLevel(2.4), BubbleLevel.mid);
    expect(bubbleLevel(2.5), BubbleLevel.high);
    expect(bubbleLevel(-3), BubbleLevel.low);
  });

  test('Tier 라벨', () {
    expect(Tier.values.map((t) => t.label), ['최고', '괜찮', '별로']);
  });
}
```

`app/test/domain/ranking_session_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jjinhugi/domain/ranking_session.dart';

void main() {
  test('후보가 없으면 바로 끝, 위치 0', () {
    final s = RankingSession([]);
    expect(s.done, isTrue);
    expect(s.current, isNull);
    expect(s.index, 0);
  });

  test('항상 새 식당이 더 좋으면 맨 위', () {
    final s = RankingSession(['a', 'b', 'c']);
    final asked = <String>[];
    while (!s.done) {
      asked.add(s.current!);
      s.answer(newIsBetter: true);
    }
    expect(s.index, 0);
    expect(asked, ['b', 'a']);
  });

  test('항상 비교 식당이 더 좋으면 맨 아래', () {
    final s = RankingSession(['a', 'b', 'c']);
    while (!s.done) {
      s.answer(newIsBetter: false);
    }
    expect(s.index, 3);
  });

  test('중간 삽입', () {
    final s = RankingSession(['a', 'b', 'c', 'd']);
    // mid=2(c): 새 식당이 더 좋음 → hi=2, mid=1(b): 비교가 더 좋음 → lo=2
    expect(s.current, 'c');
    s.answer(newIsBetter: true);
    expect(s.current, 'b');
    s.answer(newIsBetter: false);
    expect(s.done, isTrue);
    expect(s.index, 2);
  });

  test('질문 횟수는 최대 ceil(log2(n+1))', () {
    for (var n = 1; n <= 16; n++) {
      for (final better in [true, false]) {
        final s = RankingSession(List.generate(n, (i) => '$i'));
        var asked = 0;
        while (!s.done) {
          asked++;
          s.answer(newIsBetter: better);
        }
        var bound = 0;
        while ((1 << bound) < n + 1) {
          bound++;
        }
        expect(asked <= bound, isTrue, reason: 'n=$n better=$better asked=$asked bound=$bound');
      }
    }
  });
}
```

`app/test/domain/errors_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jjinhugi/domain/errors.dart';

void main() {
  test('알려진 코드는 한국어 문구', () {
    expect(reviewErrorText('store_mismatch'), contains('영수증'));
    expect(reviewErrorText('date_expired'), contains('30일'));
    expect(reviewErrorText('duplicate'), contains('이미'));
    expect(reviewErrorText('daily_limit'), contains('하루'));
    expect(reviewErrorText('out_of_region'), contains('베타'));
    expect(reviewErrorText('ocr_unavailable'), contains('다시'));
    expect(reviewErrorText('unreadable'), contains('읽'));
  });
  test('필드명(invalid-argument)은 입력 확인 문구', () {
    expect(reviewErrorText('text'), contains('입력'));
    expect(reviewErrorText('eventStars'), contains('입력'));
  });
  test('null/알 수 없는 값은 기본 문구', () {
    expect(reviewErrorText(null), '알 수 없는 오류가 발생했어요. 잠시 후 다시 시도해 주세요.');
  });
}
```

`app/test/domain/time_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jjinhugi/core/time.dart';

void main() {
  test('UTC 9/30 15:00 은 KST 10월', () {
    expect(kstMonth(DateTime.utc(2026, 9, 30, 15)), '2026-10');
  });
  test('UTC 10/31 14:59 은 아직 10월', () {
    expect(kstMonth(DateTime.utc(2026, 10, 31, 14, 59)), '2026-10');
  });
}
```

`app/test/domain/models_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jjinhugi/domain/models.dart';
import 'package:jjinhugi/domain/score.dart';

void main() {
  test('Restaurant: 점수 null과 정수 숫자 처리', () {
    final r = Restaurant.fromMap('p1', {
      'name': '찐국밥', 'address': '서울 성동구 성수동2가 1', 'region': 'seongsu',
      'realScore': 8, 'eventScore': null, 'bubble': null, 'reviewCount': 3, 'eventReviewCount': 0,
    });
    expect(r.realScore, 8.0);
    expect(r.eventScore, isNull);
    expect(r.toPlace().placeId, 'p1');
    expect(r.toPlace().region, 'seongsu');
  });

  test('Restaurant: 후기 없는 식당은 필드가 없어도 파싱', () {
    final r = Restaurant.fromMap('p2', {'name': 'x', 'address': 'y', 'region': null});
    expect(r.realScore, isNull);
    expect(r.reviewCount, 0);
    expect(r.region, isNull);
  });

  test('Review 파싱', () {
    final v = Review.fromMap('u1_p1', {
      'uid': 'u1', 'restaurantId': 'p1', 'tier': 'bad', 'personalScore': 2, 'eventJoined': true,
      'eventStars': 5, 'text': '별로였어요 이벤트로 갔음', 'photos': ['photos/u1/a.jpg'],
      'visitDate': '2026-10-06', 'likeCount': 3,
    });
    expect(v.tier, Tier.bad);
    expect(v.personalScore, 2.0);
    expect(v.eventStars, 5);
    expect(v.photos, ['photos/u1/a.jpg']);
    expect(v.createdAt, isNull);
  });

  test('AppUser 랭킹 파싱 (없는 등급은 빈 리스트)', () {
    final u = AppUser.fromMap('u1', {
      'nickname': '찐이', 'title': '찐린이', 'likesReceived': 0, 'verifiedReviewCount': 1,
      'ranking': {'best': ['a', 'b']},
    });
    expect(u.ranking[Tier.best], ['a', 'b']);
    expect(u.ranking[Tier.ok], isEmpty);
    expect(u.ranking[Tier.bad], isEmpty);
  });

  test('SubmitInput.toMap는 콜러블 계약 그대로', () {
    const i = SubmitInput(
      placeId: 'p1', receiptPath: 'receipts/u1/x.jpg', tier: Tier.ok, rankIndex: 2,
      eventJoined: true, eventStars: 4, text: '무난했어요 괜찮아요 ㅎㅎ', photos: ['photos/u1/a.jpg'],
    );
    expect(i.toMap(), {
      'placeId': 'p1', 'receiptPath': 'receipts/u1/x.jpg', 'tier': 'ok', 'rankIndex': 2,
      'eventJoined': true, 'eventStars': 4, 'text': '무난했어요 괜찮아요 ㅎㅎ', 'photos': ['photos/u1/a.jpg'],
    });
  });

  test('PlaceResult 파싱', () {
    final p = PlaceResult.fromMap({'placeId': 'k1', 'name': '찐', 'address': '서울', 'region': null, 'lat': 37.5});
    expect(p.region, isNull);
    expect(p.name, '찐');
  });

  test('Crown 파싱', () {
    final c = Crown.fromMap({'uid': 'seed1', 'likes': 16, 'status': 'confirmed'});
    expect(c.uid, 'seed1');
    expect(c.isConfirmed, isTrue);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd app && flutter test test/domain`
Expected: FAIL — `Target of URI doesn't exist: 'package:jjinhugi/domain/score.dart'` 등

- [ ] **Step 3: 구현**

`app/lib/core/time.dart`:
```dart
String kstMonth(DateTime now) {
  final k = now.toUtc().add(const Duration(hours: 9));
  return '${k.year}-${k.month.toString().padLeft(2, '0')}';
}
```

`app/lib/domain/score.dart`:
```dart
enum Tier { best, ok, bad }

extension TierX on Tier {
  String get label => switch (this) { Tier.best => '최고', Tier.ok => '괜찮', Tier.bad => '별로' };
}

double round1(double x) => (x * 10).round() / 10;

/// 백엔드 functions/src/scoring.ts 의 personalScore 와 같은 공식.
double personalScore(Tier tier, int index, int n) {
  final (lo, hi) = switch (tier) {
    Tier.best => (7.0, 10.0),
    Tier.ok => (4.0, 7.0),
    Tier.bad => (0.0, 4.0),
  };
  return round1(hi - ((hi - lo) * (index + 0.5)) / n);
}

String scoreText(double? v) => v == null ? '데이터 부족' : v.toStringAsFixed(1);

String bubbleText(double? v) => v == null ? '-' : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}';

enum BubbleLevel { unknown, low, mid, high }

BubbleLevel bubbleLevel(double? v) {
  if (v == null) return BubbleLevel.unknown;
  if (v < 1) return BubbleLevel.low;
  if (v < 2.5) return BubbleLevel.mid;
  return BubbleLevel.high;
}
```

`app/lib/domain/ranking_session.dart`:
```dart
/// 새 식당을 같은 등급의 기존 식당 목록(좋은 순)에 끼워 넣을 위치를 이진 탐색으로 찾는다.
class RankingSession {
  RankingSession(this.candidates) : _hi = candidates.length;

  final List<String> candidates;
  int _lo = 0;
  int _hi;

  bool get done => _lo >= _hi;
  String? get current => done ? null : candidates[(_lo + _hi) ~/ 2];

  /// [done]일 때 삽입 위치(0 = 맨 위).
  int get index => _lo;

  void answer({required bool newIsBetter}) {
    final mid = (_lo + _hi) ~/ 2;
    if (newIsBetter) {
      _hi = mid;
    } else {
      _lo = mid + 1;
    }
  }
}
```

`app/lib/domain/errors.dart`:
```dart
const _messages = {
  'place_not_found': '식당 정보를 찾을 수 없어요. 다시 검색해 주세요.',
  'out_of_region': '아직 베타 지역이 아니에요. 성수에서 먼저 만나요!',
  'daily_limit': '하루에 쓸 수 있는 후기는 5개예요. 내일 다시 써 주세요.',
  'ocr_unavailable': '영수증 확인 서버가 바빠요. 잠시 후 다시 시도해 주세요. 작성한 내용은 그대로예요.',
  'unreadable': '영수증을 읽지 못했어요. 글씨가 잘 보이게 다시 찍어 주세요.',
  'store_mismatch': '영수증의 가게가 선택한 식당과 달라요. 해당 식당의 영수증을 올려 주세요.',
  'date_expired': '영수증 날짜가 달라요. 방문 후 30일 이내의 영수증만 쓸 수 있어요.',
  'duplicate': '이미 사용된 영수증이에요.',
  'kakao_unavailable': '식당 검색이 잠시 안 돼요. 잠시 후 다시 시도해 주세요.',
  'login_required': '로그인이 필요해요.',
  'no_user': '프로필을 만드는 중이에요. 잠시 후 다시 시도해 주세요.',
};

const _fields = {'placeId', 'receiptPath', 'tier', 'rankIndex', 'eventJoined', 'eventStars', 'text', 'photos', 'query'};

String reviewErrorText(String? message) {
  if (message != null && _messages.containsKey(message)) return _messages[message]!;
  if (message != null && _fields.contains(message)) return '입력값을 확인해 주세요. ($message)';
  return '알 수 없는 오류가 발생했어요. 잠시 후 다시 시도해 주세요.';
}
```

`app/lib/domain/models.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'score.dart';

double? _d(dynamic v) => (v as num?)?.toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

enum RestaurantSort { real, bubble }

enum ReviewSort { likes, recent }

class PlaceResult {
  const PlaceResult({required this.placeId, required this.name, required this.address, this.region});
  final String placeId;
  final String name;
  final String address;
  final String? region;

  factory PlaceResult.fromMap(Map<String, dynamic> m) => PlaceResult(
        placeId: m['placeId'] as String,
        name: m['name'] as String,
        address: (m['address'] as String?) ?? '',
        region: m['region'] as String?,
      );
}

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.address,
    this.region,
    this.realScore,
    this.eventScore,
    this.bubble,
    this.reviewCount = 0,
    this.eventReviewCount = 0,
  });
  final String id;
  final String name;
  final String address;
  final String? region;
  final double? realScore;
  final double? eventScore;
  final double? bubble;
  final int reviewCount;
  final int eventReviewCount;

  factory Restaurant.fromMap(String id, Map<String, dynamic> m) => Restaurant(
        id: id,
        name: m['name'] as String,
        address: (m['address'] as String?) ?? '',
        region: m['region'] as String?,
        realScore: _d(m['realScore']),
        eventScore: _d(m['eventScore']),
        bubble: _d(m['bubble']),
        reviewCount: _i(m['reviewCount']),
        eventReviewCount: _i(m['eventReviewCount']),
      );

  PlaceResult toPlace() => PlaceResult(placeId: id, name: name, address: address, region: region);
}

class Review {
  const Review({
    required this.id,
    required this.uid,
    required this.restaurantId,
    required this.tier,
    required this.personalScore,
    required this.eventJoined,
    this.eventStars,
    required this.text,
    required this.photos,
    required this.visitDate,
    required this.likeCount,
    this.createdAt,
  });
  final String id;
  final String uid;
  final String restaurantId;
  final Tier tier;
  final double personalScore;
  final bool eventJoined;
  final int? eventStars;
  final String text;
  final List<String> photos;
  final String visitDate;
  final int likeCount;
  final DateTime? createdAt;

  factory Review.fromMap(String id, Map<String, dynamic> m) => Review(
        id: id,
        uid: m['uid'] as String,
        restaurantId: m['restaurantId'] as String,
        tier: Tier.values.byName(m['tier'] as String),
        personalScore: _d(m['personalScore']) ?? 0,
        eventJoined: (m['eventJoined'] as bool?) ?? false,
        eventStars: (m['eventStars'] as num?)?.toInt(),
        text: (m['text'] as String?) ?? '',
        photos: List<String>.from((m['photos'] as List?) ?? const []),
        visitDate: (m['visitDate'] as String?) ?? '',
        likeCount: _i(m['likeCount']),
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.nickname,
    required this.title,
    required this.likesReceived,
    required this.verifiedReviewCount,
    required this.ranking,
  });
  final String uid;
  final String nickname;
  final String title;
  final int likesReceived;
  final int verifiedReviewCount;
  final Map<Tier, List<String>> ranking;

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) {
    final r = (m['ranking'] as Map?) ?? const {};
    return AppUser(
      uid: uid,
      nickname: (m['nickname'] as String?) ?? '',
      title: (m['title'] as String?) ?? '찐린이',
      likesReceived: _i(m['likesReceived']),
      verifiedReviewCount: _i(m['verifiedReviewCount']),
      ranking: {for (final t in Tier.values) t: List<String>.from((r[t.name] as List?) ?? const [])},
    );
  }
}

class Crown {
  const Crown({required this.uid, required this.likes, required this.status});
  final String uid;
  final int likes;
  final String status;
  bool get isConfirmed => status == 'confirmed';

  factory Crown.fromMap(Map<String, dynamic> m) =>
      Crown(uid: m['uid'] as String, likes: _i(m['likes']), status: (m['status'] as String?) ?? 'pending');
}

class SubmitInput {
  const SubmitInput({
    required this.placeId,
    required this.receiptPath,
    required this.tier,
    required this.rankIndex,
    required this.eventJoined,
    this.eventStars,
    required this.text,
    required this.photos,
  });
  final String placeId;
  final String receiptPath;
  final Tier tier;
  final int rankIndex;
  final bool eventJoined;
  final int? eventStars;
  final String text;
  final List<String> photos;

  Map<String, dynamic> toMap() => {
        'placeId': placeId,
        'receiptPath': receiptPath,
        'tier': tier.name,
        'rankIndex': rankIndex,
        'eventJoined': eventJoined,
        'eventStars': eventStars,
        'text': text,
        'photos': photos,
      };
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd app && flutter test test/domain && flutter analyze`
Expected: PASS (score 6, ranking_session 5, errors 3, time 2, models 7), `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add app/lib/core/time.dart app/lib/domain app/test/domain
git commit -m "feat(app): add scoring, ranking session, error text and models"
```

---

### Task 3: Backend/Auth 계층 + 로그인 + 라우터

**Files:**
- Create: `app/lib/data/backend.dart`, `app/lib/data/auth_service.dart`, `app/lib/data/providers.dart`, `app/lib/router.dart`, `app/lib/features/login/login_screen.dart`
- Create (placeholder 화면, 이후 Task에서 교체): `app/lib/features/home/home_screen.dart`, `app/lib/features/restaurant/restaurant_screen.dart`, `app/lib/features/write/write_review_screen.dart`, `app/lib/features/profile/profile_screen.dart`
- Modify: `app/lib/app.dart`
- Create: `app/test/helpers.dart`
- Test: `app/test/features/login_test.dart`

**Interfaces:**
- Consumes: 모델·enum (Task 2), `functionsRegion` (Task 1)
- Produces:
  - `abstract class Backend` — 아래 메서드
    - `Stream<List<Restaurant>> watchRestaurants(String region, RestaurantSort sort)`
    - `Stream<Restaurant?> watchRestaurant(String id)`
    - `Stream<List<Review>> watchReviews(String restaurantId, ReviewSort sort)`
    - `Stream<AppUser?> watchUser(String uid)`
    - `Future<Map<String, Restaurant>> getRestaurants(List<String> ids)`
    - `Future<Crown?> getCrown(String region, String month)` — 확정(`confirmed`)된 것만, 없으면 null
    - `Future<List<PlaceResult>> searchPlaces(String query)`
    - `Future<String> uploadImage(String folder, Uint8List bytes, String contentType)` — 저장 경로 반환(`{folder}/{uid}/{uuid}.jpg`)
    - `Future<String> submitReview(SubmitInput input)` — reviewId 반환
    - `Stream<bool> watchLiked(String reviewId)`
    - `Future<void> setLike(String reviewId, bool on)`
    - `Future<void> report(String reviewId, String reason)`
    - `Future<String> downloadUrl(String path)`
  - `class FirebaseBackend implements Backend`
  - `abstract class AuthService { String? get currentUid; Stream<String?> get uidChanges; Future<void> signInDebug(String nickname); Future<void> signOut(); }`
  - `class FirebaseAuthService implements AuthService`
  - providers (`providers.dart`):
    - `backendProvider: Provider<Backend>`, `authServiceProvider: Provider<AuthService>`
    - `imagePickerProvider: Provider<Future<XFile?> Function()>`, `photosPickerProvider: Provider<Future<List<XFile>> Function()>`
    - `restaurantsProvider: StreamProvider.family<List<Restaurant>, (String, RestaurantSort)>`
    - `restaurantProvider: StreamProvider.family<Restaurant?, String>`
    - `reviewsProvider: StreamProvider.family<List<Review>, (String, ReviewSort)>`
    - `userProvider: StreamProvider.family<AppUser?, String>`
    - `likedProvider: StreamProvider.family<bool, String>`
    - `crownProvider: FutureProvider.family<Crown?, String>` (키: 지역 id, 이번 KST 월 기준)
    - `restaurantsByIdsProvider: FutureProvider.family<Map<String, Restaurant>, String>` (키: id를 `,`로 이은 문자열, 빈 문자열이면 빈 맵)
  - `routerProvider: Provider<GoRouter>` — 경로 `/login`, `/`, `/r/:id`, `/write`(extra: `PlaceResult?`), `/u/:uid`. 로그아웃 상태는 `/login`으로 리다이렉트
  - test helpers (`test/helpers.dart`): `FakeBackend`, `FakeAuth`, `Widget harness({required Widget child, required FakeBackend backend, FakeAuth? auth, PlaceResult? ...})`

- [ ] **Step 1: 테스트 헬퍼와 실패하는 테스트 작성**

`app/test/helpers.dart`:
```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jjinhugi/data/auth_service.dart';
import 'package:jjinhugi/data/backend.dart';
import 'package:jjinhugi/data/providers.dart';
import 'package:jjinhugi/domain/models.dart';

class FakeAuth implements AuthService {
  FakeAuth([this.uid = 'me']);
  String? uid;
  String? lastNickname;
  bool signedOut = false;

  @override
  String? get currentUid => uid;
  @override
  Stream<String?> get uidChanges => Stream.value(uid);
  @override
  Future<void> signInDebug(String nickname) async {
    lastNickname = nickname;
    uid = 'me';
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    uid = null;
  }
}

class FakeBackend extends Fake implements Backend {
  List<Restaurant> restaurants = [];
  List<Review> reviews = [];
  Map<String, AppUser> users = {};
  Map<String, bool> liked = {};
  List<PlaceResult> places = [];
  Crown? crown;
  SubmitInput? lastSubmit;
  Object? submitError;
  final likeCalls = <(String, bool)>[];
  final reports = <(String, String)>[];
  final uploads = <String>[];
  final searched = <String>[];

  @override
  Stream<List<Restaurant>> watchRestaurants(String region, RestaurantSort sort) => Stream.value(restaurants);
  @override
  Stream<Restaurant?> watchRestaurant(String id) => Stream.value(restaurants.where((r) => r.id == id).firstOrNull);
  @override
  Stream<List<Review>> watchReviews(String restaurantId, ReviewSort sort) => Stream.value(reviews);
  @override
  Stream<AppUser?> watchUser(String uid) => Stream.value(users[uid]);
  @override
  Future<Map<String, Restaurant>> getRestaurants(List<String> ids) async => {
        for (final r in restaurants)
          if (ids.contains(r.id)) r.id: r
      };
  @override
  Future<Crown?> getCrown(String region, String month) async => crown;
  @override
  Future<List<PlaceResult>> searchPlaces(String query) async {
    searched.add(query);
    return places;
  }

  @override
  Future<String> uploadImage(String folder, Uint8List bytes, String contentType) async {
    final path = '$folder/me/${uploads.length}.jpg';
    uploads.add(path);
    return path;
  }

  @override
  Future<String> submitReview(SubmitInput input) async {
    if (submitError != null) throw submitError!;
    lastSubmit = input;
    return 'me_${input.placeId}';
  }

  @override
  Stream<bool> watchLiked(String reviewId) => Stream.value(liked[reviewId] ?? false);
  @override
  Future<void> setLike(String reviewId, bool on) async => likeCalls.add((reviewId, on));
  @override
  Future<void> report(String reviewId, String reason) async => reports.add((reviewId, reason));
  @override
  Future<String> downloadUrl(String path) async => 'http://localhost/$path';
}

/// 화면 하나를 `/` 로 띄우고, 이동 대상 경로는 글자만 보이는 스텁으로 대체한다.
Widget harness({
  required Widget child,
  required FakeBackend backend,
  FakeAuth? auth,
  List<Override> overrides = const [],
}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => child),
    GoRoute(path: '/login', builder: (_, __) => const Text('login-page')),
    GoRoute(path: '/r/:id', builder: (_, s) => Text('detail:${s.pathParameters['id']}')),
    GoRoute(path: '/write', builder: (_, s) => Text('write:${(s.extra as PlaceResult?)?.placeId ?? ''}')),
    GoRoute(path: '/u/:uid', builder: (_, s) => Text('profile:${s.pathParameters['uid']}')),
  ]);
  return ProviderScope(
    overrides: [
      backendProvider.overrideWithValue(backend),
      authServiceProvider.overrideWithValue(auth ?? FakeAuth()),
      ...overrides,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

AppUser appUser(String uid, {int verified = 1, Map<String, List<String>> ranking = const {}}) => AppUser.fromMap(uid, {
      'nickname': '닉-$uid',
      'title': '찐린이',
      'likesReceived': 0,
      'verifiedReviewCount': verified,
      'ranking': ranking,
    });
```

`app/test/features/login_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjinhugi/features/login/login_screen.dart';

import '../helpers.dart';

void main() {
  testWidgets('닉네임을 입력하고 테스트 로그인하면 홈(/)으로 이동', (tester) async {
    final auth = FakeAuth(null);
    await tester.pumpWidget(harness(child: const LoginScreen(), backend: FakeBackend(), auth: auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '찐테스터');
    await tester.tap(find.text('테스트 로그인'));
    await tester.pumpAndSettle();

    expect(auth.lastNickname, '찐테스터');
  });

  testWidgets('닉네임이 비어 있으면 로그인하지 않음', (tester) async {
    final auth = FakeAuth(null);
    await tester.pumpWidget(harness(child: const LoginScreen(), backend: FakeBackend(), auth: auth));
    await tester.tap(find.text('테스트 로그인'));
    await tester.pump();
    expect(auth.lastNickname, isNull);
    expect(find.text('닉네임을 입력해 주세요'), findsOneWidget);
  });

  testWidgets('카카오·Apple 로그인은 준비 중 표시', (tester) async {
    await tester.pumpWidget(harness(child: const LoginScreen(), backend: FakeBackend(), auth: FakeAuth(null)));
    expect(find.text('카카오로 시작하기 (준비 중)'), findsOneWidget);
    expect(find.text('Apple로 시작하기 (준비 중)'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd app && flutter test test/features/login_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:jjinhugi/data/auth_service.dart'`

- [ ] **Step 3: 데이터 계층 구현**

`app/lib/data/auth_service.dart`:
```dart
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/env.dart';

abstract class AuthService {
  String? get currentUid;
  Stream<String?> get uidChanges;

  /// 에뮬레이터 전용 테스트 로그인. 닉네임이 같으면 같은 계정으로 다시 로그인된다.
  Future<void> signInDebug(String nickname);
  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Stream<String?> get uidChanges => _auth.authStateChanges().map((u) => u?.uid);

  @override
  Future<void> signInDebug(String nickname) async {
    final email = '${base64Url.encode(utf8.encode(nickname)).replaceAll('=', '')}@debug.jjinhugi.test';
    const password = 'debug-pass-1234';
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found' && e.code != 'invalid-credential') rethrow;
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
    }
    await _auth.currentUser!.updateDisplayName(nickname);
    await _auth.currentUser!.getIdToken(true);
    await FirebaseFunctions.instanceFor(region: functionsRegion).httpsCallable('ensureUser').call();
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
```

`app/lib/data/backend.dart`:
```dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/env.dart';
import '../domain/models.dart';

abstract class Backend {
  Stream<List<Restaurant>> watchRestaurants(String region, RestaurantSort sort);
  Stream<Restaurant?> watchRestaurant(String id);
  Stream<List<Review>> watchReviews(String restaurantId, ReviewSort sort);
  Stream<AppUser?> watchUser(String uid);
  Future<Map<String, Restaurant>> getRestaurants(List<String> ids);
  Future<Crown?> getCrown(String region, String month);
  Future<List<PlaceResult>> searchPlaces(String query);
  Future<String> uploadImage(String folder, Uint8List bytes, String contentType);
  Future<String> submitReview(SubmitInput input);
  Stream<bool> watchLiked(String reviewId);
  Future<void> setLike(String reviewId, bool on);
  Future<void> report(String reviewId, String reason);
  Future<String> downloadUrl(String path);
}

class FirebaseBackend implements Backend {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseFunctions get _fn => FirebaseFunctions.instanceFor(region: functionsRegion);
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Stream<List<Restaurant>> watchRestaurants(String region, RestaurantSort sort) => _db
      .collection('restaurants')
      .where('region', isEqualTo: region)
      .orderBy(sort == RestaurantSort.real ? 'realScore' : 'bubble', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) Restaurant.fromMap(d.id, d.data())]);

  @override
  Stream<Restaurant?> watchRestaurant(String id) =>
      _db.doc('restaurants/$id').snapshots().map((s) => s.exists ? Restaurant.fromMap(s.id, s.data()!) : null);

  @override
  Stream<List<Review>> watchReviews(String restaurantId, ReviewSort sort) => _db
      .collection('reviews')
      .where('restaurantId', isEqualTo: restaurantId)
      .orderBy(sort == ReviewSort.likes ? 'likeCount' : 'createdAt', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) Review.fromMap(d.id, d.data())]);

  @override
  Stream<AppUser?> watchUser(String uid) =>
      _db.doc('users/$uid').snapshots().map((s) => s.exists ? AppUser.fromMap(s.id, s.data()!) : null);

  @override
  Future<Map<String, Restaurant>> getRestaurants(List<String> ids) async {
    final snaps = await Future.wait(ids.map((id) => _db.doc('restaurants/$id').get()));
    return {
      for (final s in snaps)
        if (s.exists) s.id: Restaurant.fromMap(s.id, s.data()!)
    };
  }

  @override
  Future<Crown?> getCrown(String region, String month) async {
    final s = await _db.doc('crowns/${month}_$region').get();
    if (!s.exists) return null;
    final c = Crown.fromMap(s.data()!);
    return c.isConfirmed ? c : null;
  }

  @override
  Future<List<PlaceResult>> searchPlaces(String query) async {
    final res = await _fn.httpsCallable('searchPlaces').call({'query': query});
    return [for (final e in res.data as List) PlaceResult.fromMap(Map<String, dynamic>.from(e as Map))];
  }

  @override
  Future<String> uploadImage(String folder, Uint8List bytes, String contentType) async {
    final path = '$folder/$_uid/${const Uuid().v4()}.jpg';
    await FirebaseStorage.instance.ref(path).putData(bytes, SettableMetadata(contentType: contentType));
    return path;
  }

  @override
  Future<String> submitReview(SubmitInput input) async {
    final res = await _fn.httpsCallable('submitReview').call(input.toMap());
    return (res.data as Map)['reviewId'] as String;
  }

  @override
  Stream<bool> watchLiked(String reviewId) => _db.doc('reviews/$reviewId/likes/$_uid').snapshots().map((s) => s.exists);

  @override
  Future<void> setLike(String reviewId, bool on) {
    final ref = _db.doc('reviews/$reviewId/likes/$_uid');
    return on ? ref.set({'createdAt': FieldValue.serverTimestamp()}) : ref.delete();
  }

  @override
  Future<void> report(String reviewId, String reason) => _db.collection('reports').add({
        'reviewId': reviewId,
        'reporterUid': _uid,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<String> downloadUrl(String path) => FirebaseStorage.instance.ref(path).getDownloadURL();
}
```

`app/lib/data/providers.dart`:
```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/time.dart';
import '../domain/models.dart';
import 'auth_service.dart';
import 'backend.dart';

final backendProvider = Provider<Backend>((ref) => FirebaseBackend());
final authServiceProvider = Provider<AuthService>((ref) => FirebaseAuthService());

/// 영수증 1장 선택. 모바일은 카메라, 웹은 파일 선택.
final imagePickerProvider = Provider<Future<XFile?> Function()>(
  (ref) => () => ImagePicker().pickImage(source: kIsWeb ? ImageSource.gallery : ImageSource.camera, maxWidth: 1600, imageQuality: 85),
);

/// 후기 사진 여러 장 선택.
final photosPickerProvider = Provider<Future<List<XFile>> Function()>(
  (ref) => () => ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 85),
);

final restaurantsProvider = StreamProvider.family<List<Restaurant>, (String, RestaurantSort)>(
  (ref, k) => ref.watch(backendProvider).watchRestaurants(k.$1, k.$2),
);
final restaurantProvider =
    StreamProvider.family<Restaurant?, String>((ref, id) => ref.watch(backendProvider).watchRestaurant(id));
final reviewsProvider = StreamProvider.family<List<Review>, (String, ReviewSort)>(
  (ref, k) => ref.watch(backendProvider).watchReviews(k.$1, k.$2),
);
final userProvider = StreamProvider.family<AppUser?, String>((ref, uid) => ref.watch(backendProvider).watchUser(uid));
final likedProvider = StreamProvider.family<bool, String>((ref, id) => ref.watch(backendProvider).watchLiked(id));
final crownProvider = FutureProvider.family<Crown?, String>(
  (ref, region) => ref.watch(backendProvider).getCrown(region, kstMonth(DateTime.now())),
);
final restaurantsByIdsProvider = FutureProvider.family<Map<String, Restaurant>, String>((ref, joined) async {
  if (joined.isEmpty) return {};
  return ref.watch(backendProvider).getRestaurants(joined.split(','));
});
```

- [ ] **Step 4: 화면 구현 (로그인 + 임시 화면)**

`app/lib/features/login/login_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nick = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _login() async {
    final nick = _nick.text.trim();
    if (nick.isEmpty) {
      setState(() => _error = '닉네임을 입력해 주세요');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref.read(authServiceProvider).signInDebug(nick.length > 10 ? nick.substring(0, 10) : nick);
    } catch (e) {
      if (mounted) setState(() => _error = '로그인에 실패했어요: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('찐후기', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 4),
                const Text('리뷰 이벤트 없이 쓴 진짜 후기', textAlign: TextAlign.center),
                const SizedBox(height: 32),
                const OutlinedButton(onPressed: null, child: Text('카카오로 시작하기 (준비 중)')),
                const SizedBox(height: 8),
                const OutlinedButton(onPressed: null, child: Text('Apple로 시작하기 (준비 중)')),
                const Divider(height: 40),
                const Text('개발용 테스트 로그인 (에뮬레이터)', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nick,
                  maxLength: 10,
                  decoration: InputDecoration(labelText: '닉네임', errorText: _error, border: const OutlineInputBorder()),
                  onSubmitted: (_) => _login(),
                ),
                FilledButton(onPressed: _busy ? null : _login, child: const Text('테스트 로그인')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

임시 화면 4개 (이후 Task에서 파일 전체를 교체):

`app/lib/features/home/home_screen.dart`:
```dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('홈')));
}
```
`app/lib/features/restaurant/restaurant_screen.dart`:
```dart
import 'package:flutter/material.dart';

class RestaurantScreen extends StatelessWidget {
  const RestaurantScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text('식당 $id')));
}
```
`app/lib/features/write/write_review_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../../domain/models.dart';

class WriteReviewScreen extends StatelessWidget {
  const WriteReviewScreen({super.key, this.initialPlace});
  final PlaceResult? initialPlace;
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('후기 쓰기')));
}
```
`app/lib/features/profile/profile_screen.dart`:
```dart
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text('프로필 $uid')));
}
```

`app/lib/router.dart`:
```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/providers.dart';
import 'domain/models.dart';
import 'features/home/home_screen.dart';
import 'features/login/login_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/restaurant/restaurant_screen.dart';
import 'features/write/write_review_screen.dart';

class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> s) {
    _sub = s.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authServiceProvider);
  final refresh = _StreamListenable(auth.uidChanges);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = auth.currentUid != null;
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn) return atLogin ? null : '/login';
      if (atLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/r/:id', builder: (_, s) => RestaurantScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/write', builder: (_, s) => WriteReviewScreen(initialPlace: s.extra as PlaceResult?)),
      GoRoute(path: '/u/:uid', builder: (_, s) => ProfileScreen(uid: s.pathParameters['uid']!)),
    ],
  );
});
```

`app/lib/app.dart`를 교체:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

class JjinApp extends ConsumerWidget {
  const JjinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '찐후기',
      theme: ThemeData(colorSchemeSeed: const Color(0xFFE8590C), useMaterial3: true),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
```

- [ ] **Step 5: 통과 확인**

Run: `cd app && flutter test && flutter analyze`
Expected: PASS (domain 23 + login 3), `No issues found!`

> `harness`의 `/` 라우트는 `FakeAuth(null)` 이어도 리다이렉트가 없으므로 로그인 화면이 그대로 보인다. 실제 리다이렉트는 `routerProvider`에 있고 Task 8의 수동 점검에서 확인한다.

- [ ] **Step 6: 커밋**

```bash
git add app
git commit -m "feat(app): add backend/auth layer, providers, router and login screen"
```

---

### Task 4: 홈 화면 (식당 목록 + 정렬 + 대마왕 배너)

**Files:**
- Modify (전체 교체): `app/lib/features/home/home_screen.dart`
- Create: `app/lib/features/home/restaurant_card.dart`
- Test: `app/test/features/home_test.dart`

**Interfaces:**
- Consumes: `restaurantsProvider`, `crownProvider`, `userProvider`, `authServiceProvider` (Task 3) / `betaRegions` / `scoreText`, `bubbleText`, `bubbleLevel` (Task 2)
- Produces:
  - `class HomeScreen extends ConsumerStatefulWidget` — 상단 지역 표시, 대마왕 배너, 정렬 칩(`찐점수순` / `거품 큰 순`), 식당 카드 목록, `후기 쓰기` FAB, 프로필 아이콘(`/u/{내uid}`)
  - `class RestaurantCard extends StatelessWidget { RestaurantCard({required Restaurant restaurant}) }` — 탭하면 `/r/{id}`

- [ ] **Step 1: 실패하는 테스트 작성**

`app/test/features/home_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjinhugi/domain/models.dart';
import 'package:jjinhugi/features/home/home_screen.dart';

import '../helpers.dart';

Restaurant r(String id, String name, {double? real, double? event, double? bubble, int count = 0}) => Restaurant(
      id: id, name: name, address: '서울 성동구 성수동2가 1', region: 'seongsu',
      realScore: real, eventScore: event, bubble: bubble, reviewCount: count,
    );

void main() {
  testWidgets('식당 카드: 찐점수·이벤트점수·거품지수·후기 수', (tester) async {
    final b = FakeBackend()
      ..restaurants = [r('a', '성수 찐고기', real: 2.3, event: 10, bubble: 7.7, count: 3)];
    await tester.pumpWidget(harness(child: const HomeScreen(), backend: b));
    await tester.pumpAndSettle();

    expect(find.text('성수 찐고기'), findsOneWidget);
    expect(find.text('찐 2.3'), findsOneWidget);
    expect(find.text('이벤트 10.0'), findsOneWidget);
    expect(find.text('거품 +7.7'), findsOneWidget);
    expect(find.text('후기 3'), findsOneWidget);
  });

  testWidgets('데이터 부족 표시', (tester) async {
    final b = FakeBackend()..restaurants = [r('a', '신상 식당', count: 1)];
    await tester.pumpWidget(harness(child: const HomeScreen(), backend: b));
    await tester.pumpAndSettle();

    expect(find.text('찐 데이터 부족'), findsOneWidget);
    expect(find.textContaining('거품 +'), findsNothing);
  });

  testWidgets('목록이 비면 안내 문구', (tester) async {
    await tester.pumpWidget(harness(child: const HomeScreen(), backend: FakeBackend()));
    await tester.pumpAndSettle();
    expect(find.text('아직 후기가 없어요. 첫 찐후기를 남겨 보세요!'), findsOneWidget);
  });

  testWidgets('카드를 누르면 상세로 이동', (tester) async {
    final b = FakeBackend()..restaurants = [r('a', '성수 찐국밥', real: 7.8, count: 3)];
    await tester.pumpWidget(harness(child: const HomeScreen(), backend: b));
    await tester.pumpAndSettle();
    await tester.tap(find.text('성수 찐국밥'));
    await tester.pumpAndSettle();
    expect(find.text('detail:a'), findsOneWidget);
  });

  testWidgets('후기 쓰기 버튼은 /write 로 이동', (tester) async {
    await tester.pumpWidget(harness(child: const HomeScreen(), backend: FakeBackend()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('후기 쓰기'));
    await tester.pumpAndSettle();
    expect(find.text('write:'), findsOneWidget);
  });

  testWidgets('확정된 대마왕이 있으면 배너 표시, 누르면 그 유저 프로필', (tester) async {
    final b = FakeBackend()
      ..crown = const Crown(uid: 'seed1', likes: 16, status: 'confirmed')
      ..users = {'seed1': appUser('seed1')};
    await tester.pumpWidget(harness(child: const HomeScreen(), backend: b));
    await tester.pumpAndSettle();

    expect(find.textContaining('찐후기 대마왕'), findsOneWidget);
    expect(find.textContaining('닉-seed1'), findsOneWidget);
    await tester.tap(find.textContaining('찐후기 대마왕'));
    await tester.pumpAndSettle();
    expect(find.text('profile:seed1'), findsOneWidget);
  });

  testWidgets('대마왕이 없으면 배너 없음', (tester) async {
    await tester.pumpWidget(harness(child: const HomeScreen(), backend: FakeBackend()));
    await tester.pumpAndSettle();
    expect(find.textContaining('대마왕'), findsNothing);
  });

  testWidgets('정렬 칩이 두 개 있고 거품 큰 순을 선택할 수 있음', (tester) async {
    await tester.pumpWidget(harness(child: const HomeScreen(), backend: FakeBackend()));
    await tester.pumpAndSettle();
    expect(find.text('찐점수순'), findsOneWidget);
    await tester.tap(find.text('거품 큰 순'));
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '거품 큰 순'));
    expect(chip.selected, isTrue);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd app && flutter test test/features/home_test.dart`
Expected: FAIL — `찐 2.3`, `후기 쓰기` 등을 찾지 못함 (임시 화면)

- [ ] **Step 3: 구현**

`app/lib/features/home/restaurant_card.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models.dart';
import '../../domain/score.dart';

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({super.key, required this.restaurant});
  final Restaurant restaurant;

  Color _bubbleColor(BuildContext context) => switch (bubbleLevel(restaurant.bubble)) {
        BubbleLevel.high => Colors.red.shade100,
        BubbleLevel.mid => Colors.orange.shade100,
        _ => Theme.of(context).colorScheme.surfaceContainerHighest,
      };

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => context.push('/r/${r.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(r.address, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(label: Text('찐 ${scoreText(r.realScore)}'), visualDensity: VisualDensity.compact),
                  if (r.eventScore != null)
                    Chip(label: Text('이벤트 ${scoreText(r.eventScore)}'), visualDensity: VisualDensity.compact),
                  if (r.bubble != null)
                    Chip(
                      label: Text('거품 ${bubbleText(r.bubble)}'),
                      backgroundColor: _bubbleColor(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  Chip(label: Text('후기 ${r.reviewCount}'), visualDensity: VisualDensity.compact),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

`app/lib/features/home/home_screen.dart` (전체 교체):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/regions.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import 'restaurant_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final BetaRegion _region = betaRegions.first;
  RestaurantSort _sort = RestaurantSort.real;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(restaurantsProvider((_region.id, _sort)));
    return Scaffold(
      appBar: AppBar(
        title: Text('찐후기 · ${_region.name}'),
        actions: [
          IconButton(
            tooltip: '내 프로필',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/u/${ref.read(authServiceProvider).currentUid}'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/write'),
        icon: const Icon(Icons.edit),
        label: const Text('후기 쓰기'),
      ),
      body: Column(
        children: [
          _CrownBanner(regionId: _region.id),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('찐점수순'),
                  selected: _sort == RestaurantSort.real,
                  onSelected: (_) => setState(() => _sort = RestaurantSort.real),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('거품 큰 순'),
                  selected: _sort == RestaurantSort.bubble,
                  onSelected: (_) => setState(() => _sort = RestaurantSort.bubble),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('불러오지 못했어요: $e')),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('아직 후기가 없어요. 첫 찐후기를 남겨 보세요!'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: items.length,
                      itemBuilder: (_, i) => RestaurantCard(restaurant: items[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrownBanner extends ConsumerWidget {
  const _CrownBanner({required this.regionId});
  final String regionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crown = ref.watch(crownProvider(regionId)).value;
    if (crown == null) return const SizedBox.shrink();
    final nick = ref.watch(userProvider(crown.uid)).value?.nickname ?? '';
    return Material(
      color: Colors.amber.shade100,
      child: InkWell(
        onTap: () => context.push('/u/${crown.uid}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('👑 '),
              Expanded(child: Text('이번 달 찐후기 대마왕 · $nick (따봉 ${crown.likes})')),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd app && flutter test && flutter analyze`
Expected: PASS (home 8 추가), `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add app/lib/features/home app/test/features/home_test.dart
git commit -m "feat(app): add home screen with sorting and crown banner"
```

---

### Task 5: 식당 상세 + 후기 카드 (따봉·신고)

**Files:**
- Modify (전체 교체): `app/lib/features/restaurant/restaurant_screen.dart`
- Create: `app/lib/features/restaurant/review_card.dart`
- Test: `app/test/features/restaurant_test.dart`

**Interfaces:**
- Consumes: `restaurantProvider`, `reviewsProvider`, `userProvider`, `likedProvider`, `backendProvider`, `authServiceProvider` (Task 3) / 모델·점수 함수 (Task 2)
- Produces:
  - `class RestaurantScreen extends ConsumerStatefulWidget { RestaurantScreen({required String id}) }` — 점수 요약, 후기 정렬 칩(`따봉순`/`최신순`), 후기 목록, `이 식당 후기 쓰기` 버튼(`/write`, extra: `restaurant.toPlace()`)
  - `class ReviewCard extends ConsumerWidget { ReviewCard({required Review review}) }` — 작성자 닉네임·칭호, `최고 9.3` 같은 등급·점수, 이벤트 참여 라벨, 한줄평, 사진, 따봉 버튼, 신고 버튼

- [ ] **Step 1: 실패하는 테스트 작성**

`app/test/features/restaurant_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjinhugi/domain/models.dart';
import 'package:jjinhugi/domain/score.dart';
import 'package:jjinhugi/features/restaurant/restaurant_screen.dart';

import '../helpers.dart';

const place = Restaurant(
  id: 'p1', name: '성수 찐고기', address: '서울 성동구 성수동2가 31', region: 'seongsu',
  realScore: 2.3, eventScore: 10, bubble: 7.7, reviewCount: 3, eventReviewCount: 3,
);

Review review(String id, String uid, {Tier tier = Tier.bad, bool event = true, int likes = 2, String text = '이벤트 때문에 갔는데 별로였어요'}) =>
    Review(
      id: id, uid: uid, restaurantId: 'p1', tier: tier, personalScore: 2.0, eventJoined: event,
      eventStars: event ? 5 : null, text: text, photos: const [], visitDate: '2026-10-06', likeCount: likes,
    );

FakeBackend backendWith(List<Review> reviews) => FakeBackend()
  ..restaurants = [place]
  ..reviews = reviews
  ..users = {'other': appUser('other'), 'me': appUser('me')};

void main() {
  testWidgets('점수 요약과 후기 내용', (tester) async {
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: backendWith([review('other_p1', 'other')])));
    await tester.pumpAndSettle();

    expect(find.text('성수 찐고기'), findsWidgets);
    expect(find.text('찐 2.3'), findsOneWidget);
    expect(find.text('이벤트 10.0'), findsOneWidget);
    expect(find.text('거품 +7.7'), findsOneWidget);
    expect(find.text('닉-other'), findsOneWidget);
    expect(find.text('별로 2.0'), findsOneWidget);
    expect(find.textContaining('이벤트 참여'), findsOneWidget);
    expect(find.text('이벤트 때문에 갔는데 별로였어요'), findsOneWidget);
  });

  testWidgets('이벤트 미참여 후기에는 이벤트 라벨 없음', (tester) async {
    await tester.pumpWidget(harness(
        child: const RestaurantScreen(id: 'p1'), backend: backendWith([review('other_p1', 'other', event: false)])));
    await tester.pumpAndSettle();
    expect(find.textContaining('이벤트 참여'), findsNothing);
  });

  testWidgets('따봉 누르면 setLike(true), 이미 눌렀으면 setLike(false)', (tester) async {
    final b = backendWith([review('other_p1', 'other')]);
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: b));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.thumb_up_outlined));
    await tester.pumpAndSettle();
    expect(b.likeCalls, [('other_p1', true)]);

    final b2 = backendWith([review('other_p1', 'other')])..liked = {'other_p1': true};
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: b2));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.thumb_up));
    await tester.pumpAndSettle();
    expect(b2.likeCalls, [('other_p1', false)]);
  });

  testWidgets('본인 후기 따봉 비활성', (tester) async {
    final b = backendWith([review('me_p1', 'me')]);
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: b));
    await tester.pumpAndSettle();
    final btn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.thumb_up_outlined));
    expect(btn.onPressed, isNull);
  });

  testWidgets('인증 후기 없으면 따봉 안내 (쓰기 호출 안 함)', (tester) async {
    final b = backendWith([review('other_p1', 'other')])..users = {'other': appUser('other'), 'me': appUser('me', verified: 0)};
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: b));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.thumb_up_outlined));
    await tester.pumpAndSettle();
    expect(find.text('영수증 인증 후기를 1개 이상 쓰면 따봉을 줄 수 있어요'), findsOneWidget);
    expect(b.likeCalls, isEmpty);
  });

  testWidgets('신고: 사유 입력 후 접수', (tester) async {
    final b = backendWith([review('other_p1', 'other')]);
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: b));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '광고 같아요');
    await tester.tap(find.text('신고하기'));
    await tester.pumpAndSettle();
    expect(b.reports, [('other_p1', '광고 같아요')]);
    expect(find.text('신고가 접수됐어요'), findsOneWidget);
  });

  testWidgets('후기가 없으면 안내', (tester) async {
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: backendWith([])));
    await tester.pumpAndSettle();
    expect(find.text('아직 후기가 없어요'), findsOneWidget);
  });

  testWidgets('이 식당 후기 쓰기 → /write 로 식당 전달', (tester) async {
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: backendWith([])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 식당 후기 쓰기'));
    await tester.pumpAndSettle();
    expect(find.text('write:p1'), findsOneWidget);
  });

  testWidgets('작성자 이름을 누르면 프로필', (tester) async {
    await tester.pumpWidget(harness(child: const RestaurantScreen(id: 'p1'), backend: backendWith([review('other_p1', 'other')])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('닉-other'));
    await tester.pumpAndSettle();
    expect(find.text('profile:other'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd app && flutter test test/features/restaurant_test.dart`
Expected: FAIL — 텍스트를 찾지 못함 (임시 화면)

- [ ] **Step 3: 구현**

`app/lib/features/restaurant/review_card.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/score.dart';

class ReviewCard extends ConsumerWidget {
  const ReviewCard({super.key, required this.review});
  final Review review;

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _toggleLike(BuildContext context, WidgetRef ref, bool liked, AppUser? me) async {
    if (!liked && (me?.verifiedReviewCount ?? 0) < 1) {
      _snack(context, '영수증 인증 후기를 1개 이상 쓰면 따봉을 줄 수 있어요');
      return;
    }
    try {
      await ref.read(backendProvider).setLike(review.id, !liked);
    } catch (_) {
      if (context.mounted) _snack(context, '따봉을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 후기를 신고할까요?'),
        content: TextField(controller: c, maxLength: 200, decoration: const InputDecoration(labelText: '사유')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('신고하기')),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await ref.read(backendProvider).report(review.id, reason);
    if (context.mounted) _snack(context, '신고가 접수됐어요');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.read(authServiceProvider).currentUid ?? '';
    final me = ref.watch(userProvider(myUid)).value;
    final author = ref.watch(userProvider(review.uid)).value;
    final liked = ref.watch(likedProvider(review.id)).value ?? false;
    final mine = review.uid == myUid;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => context.push('/u/${review.uid}'),
                  child: Text(author?.nickname ?? '…', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                if (author != null) Chip(label: Text(author.title), visualDensity: VisualDensity.compact),
                const Spacer(),
                Text(review.visitDate, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                Text('${review.tier.label} ${scoreText(review.personalScore)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                if (review.eventJoined)
                  Text('🎁 이벤트 참여 · 별점 ${review.eventStars}', style: TextStyle(color: Colors.orange.shade800)),
              ],
            ),
            const SizedBox(height: 6),
            Text(review.text),
            if (review.photos.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [for (final p in review.photos) _Photo(path: p)],
                ),
              ),
            ],
            Row(
              children: [
                IconButton(
                  tooltip: '따봉',
                  icon: Icon(liked ? Icons.thumb_up : Icons.thumb_up_outlined),
                  onPressed: mine ? null : () => _toggleLike(context, ref, liked, me),
                ),
                Text('${review.likeCount}'),
                const Spacer(),
                IconButton(tooltip: '신고', icon: const Icon(Icons.flag_outlined), onPressed: () => _report(context, ref)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Photo extends ConsumerWidget {
  const _Photo({required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FutureBuilder<String>(
        future: ref.read(backendProvider).downloadUrl(path),
        builder: (_, snap) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 96,
            height: 96,
            child: snap.hasData ? Image.network(snap.data!, fit: BoxFit.cover) : const ColoredBox(color: Colors.black12),
          ),
        ),
      ),
    );
  }
}
```

`app/lib/features/restaurant/restaurant_screen.dart` (전체 교체):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/score.dart';
import 'review_card.dart';

class RestaurantScreen extends ConsumerStatefulWidget {
  const RestaurantScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen> {
  ReviewSort _sort = ReviewSort.likes;

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(restaurantProvider(widget.id)).value;
    final reviews = ref.watch(reviewsProvider((widget.id, _sort)));
    return Scaffold(
      appBar: AppBar(title: Text(r?.name ?? '식당')),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: Theme.of(context).textTheme.headlineSmall),
                      Text(r.address),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text('찐 ${scoreText(r.realScore)}')),
                          if (r.eventScore != null) Chip(label: Text('이벤트 ${scoreText(r.eventScore)}')),
                          if (r.bubble != null) Chip(label: Text('거품 ${bubbleText(r.bubble)}')),
                          Chip(label: Text('후기 ${r.reviewCount}')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => context.push('/write', extra: r.toPlace()),
                        icon: const Icon(Icons.edit),
                        label: const Text('이 식당 후기 쓰기'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('따봉순'),
                        selected: _sort == ReviewSort.likes,
                        onSelected: (_) => setState(() => _sort = ReviewSort.likes),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('최신순'),
                        selected: _sort == ReviewSort.recent,
                        onSelected: (_) => setState(() => _sort = ReviewSort.recent),
                      ),
                    ],
                  ),
                ),
                ...reviews.when(
                  loading: () => [const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))],
                  error: (e, _) => [Padding(padding: const EdgeInsets.all(24), child: Text('불러오지 못했어요: $e'))],
                  data: (list) => list.isEmpty
                      ? [const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('아직 후기가 없어요')))]
                      : [for (final v in list) ReviewCard(review: v)],
                ),
              ],
            ),
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd app && flutter test && flutter analyze`
Expected: PASS (restaurant 9 추가), `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add app/lib/features/restaurant app/test/features/restaurant_test.dart
git commit -m "feat(app): add restaurant detail with review cards, likes and reports"
```

---

### Task 6: 프로필 / 내 리스트

**Files:**
- Modify (전체 교체): `app/lib/features/profile/profile_screen.dart`
- Test: `app/test/features/profile_test.dart`

**Interfaces:**
- Consumes: `userProvider`, `restaurantsByIdsProvider`, `authServiceProvider` (Task 3) / `personalScore`, `scoreText`, `Tier` (Task 2)
- Produces: `class ProfileScreen extends ConsumerWidget { ProfileScreen({required String uid}) }` — 닉네임·칭호·받은 따봉, 등급 탭(최고/괜찮/별로)별 순위표(순위·식당명·개인 점수, 탭하면 `/r/{id}`), 본인이면 `로그아웃` 버튼

- [ ] **Step 1: 실패하는 테스트 작성**

`app/test/features/profile_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjinhugi/domain/models.dart';
import 'package:jjinhugi/features/profile/profile_screen.dart';

import '../helpers.dart';

Restaurant rest(String id, String name) => Restaurant(id: id, name: name, address: '서울', region: 'seongsu');

FakeBackend backend() => FakeBackend()
  ..restaurants = [rest('a', '가게A'), rest('b', '가게B'), rest('c', '가게C')]
  ..users = {
    'seed1': AppUser.fromMap('seed1', {
      'nickname': '찐미식가', 'title': '찐후기러', 'likesReceived': 16, 'verifiedReviewCount': 3,
      'ranking': {'best': ['a', 'b'], 'ok': ['c'], 'bad': []},
    }),
  };

void main() {
  testWidgets('닉네임·칭호·받은 따봉', (tester) async {
    await tester.pumpWidget(harness(child: const ProfileScreen(uid: 'seed1'), backend: backend()));
    await tester.pumpAndSettle();
    expect(find.text('찐미식가'), findsOneWidget);
    expect(find.text('찐후기러'), findsOneWidget);
    expect(find.text('받은 따봉 16'), findsOneWidget);
  });

  testWidgets('최고 탭: 순위와 개인 점수 (백엔드와 같은 공식)', (tester) async {
    await tester.pumpWidget(harness(child: const ProfileScreen(uid: 'seed1'), backend: backend()));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('가게A'), findsOneWidget);
    expect(find.text('9.3'), findsOneWidget);
    expect(find.text('가게B'), findsOneWidget);
    expect(find.text('7.8'), findsOneWidget);
  });

  testWidgets('괜찮 탭으로 전환', (tester) async {
    await tester.pumpWidget(harness(child: const ProfileScreen(uid: 'seed1'), backend: backend()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('괜찮'));
    await tester.pumpAndSettle();
    expect(find.text('가게C'), findsOneWidget);
    expect(find.text('5.5'), findsOneWidget);
  });

  testWidgets('비어 있는 등급은 안내', (tester) async {
    await tester.pumpWidget(harness(child: const ProfileScreen(uid: 'seed1'), backend: backend()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('별로'));
    await tester.pumpAndSettle();
    expect(find.text('아직 없어요'), findsOneWidget);
  });

  testWidgets('식당을 누르면 상세로', (tester) async {
    await tester.pumpWidget(harness(child: const ProfileScreen(uid: 'seed1'), backend: backend()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('가게A'));
    await tester.pumpAndSettle();
    expect(find.text('detail:a'), findsOneWidget);
  });

  testWidgets('본인 프로필에만 로그아웃 버튼', (tester) async {
    final b = backend()..users['me'] = appUser('me');
    final auth = FakeAuth('me');
    await tester.pumpWidget(harness(child: const ProfileScreen(uid: 'me'), backend: b, auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(auth.signedOut, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(harness(child: const ProfileScreen(uid: 'seed1'), backend: backend(), auth: FakeAuth('me')));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃'), findsNothing);
  });

  testWidgets('없는 유저는 안내', (tester) async {
    await tester.pumpWidget(harness(child: const ProfileScreen(uid: 'ghost'), backend: FakeBackend()));
    await tester.pumpAndSettle();
    expect(find.text('프로필을 찾을 수 없어요'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd app && flutter test test/features/profile_test.dart`
Expected: FAIL — 임시 화면이라 텍스트를 찾지 못함

- [ ] **Step 3: 구현**

`app/lib/features/profile/profile_screen.dart` (전체 교체):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/score.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider(uid));
    final mine = ref.read(authServiceProvider).currentUid == uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(mine ? '내 프로필' : '프로필'),
        actions: [
          if (mine)
            TextButton(
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
              },
              child: const Text('로그아웃'),
            ),
        ],
      ),
      body: user.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오지 못했어요: $e')),
        data: (u) => u == null ? const Center(child: Text('프로필을 찾을 수 없어요')) : _Body(user: u),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allIds = [for (final t in Tier.values) ...?user.ranking[t]];
    final names = ref.watch(restaurantsByIdsProvider(allIds.join(','))).value ?? const {};
    return DefaultTabController(
      length: Tier.values.length,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(user.nickname, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Chip(label: Text(user.title)),
                Text('받은 따봉 ${user.likesReceived}'),
              ],
            ),
          ),
          TabBar(tabs: [for (final t in Tier.values) Tab(text: t.label)]),
          Expanded(
            child: TabBarView(
              children: [
                for (final t in Tier.values)
                  _TierList(tier: t, ids: user.ranking[t] ?? const [], names: names),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TierList extends StatelessWidget {
  const _TierList({required this.tier, required this.ids, required this.names});
  final Tier tier;
  final List<String> ids;
  final Map<String, Restaurant> names;

  @override
  Widget build(BuildContext context) {
    if (ids.isEmpty) return const Center(child: Text('아직 없어요'));
    return ListView.builder(
      itemCount: ids.length,
      itemBuilder: (_, i) => ListTile(
        leading: Text('${i + 1}', style: Theme.of(context).textTheme.titleMedium),
        title: Text(names[ids[i]]?.name ?? ids[i]),
        trailing: Text(scoreText(personalScore(tier, i, ids.length))),
        onTap: () => context.push('/r/${ids[i]}'),
      ),
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd app && flutter test && flutter analyze`
Expected: PASS (profile 7 추가), `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add app/lib/features/profile app/test/features/profile_test.dart
git commit -m "feat(app): add profile screen with tiered ranking lists"
```

---

### Task 7: 후기 작성 흐름

**Files:**
- Modify (전체 교체): `app/lib/features/write/write_review_screen.dart`
- Test: `app/test/features/write_test.dart`

**Interfaces:**
- Consumes: `backendProvider`, `authServiceProvider`, `imagePickerProvider`, `photosPickerProvider` (Task 3) / `RankingSession`, `reviewErrorText`, `SubmitInput`, `PlaceResult`, `Restaurant`, `Tier` (Task 2)
- Produces: `class WriteReviewScreen extends ConsumerStatefulWidget { WriteReviewScreen({PlaceResult? initialPlace}) }`
  - 단계: 0 식당 검색 → 1 영수증 → 2 등급 → 3 비교 → 4 이벤트 → 5 한줄평·사진·제출
  - 하단 버튼: `이전` / `다음` (마지막 단계는 `제출`)
  - 문구(테스트가 의존): `검색`, `베타 지역 아님`, `영수증 사진 선택`, `영수증 선택됨`, `최고/괜찮/별로`(ChoiceChip), `이번 식당이 더 좋았어요`, `비교 식당이 더 좋았어요`, `순위가 정해졌어요`, `리뷰 이벤트에 참여했나요?`, `이벤트 때 준 별점`, 별 버튼 Key `star-1`~`star-5`, `한줄평`, `사진 추가`, `제출`
  - 성공하면 `/r/{placeId}` 로 이동. 실패하면 오류 문구를 화면에 보이고 입력은 유지

- [ ] **Step 1: 실패하는 테스트 작성**

`app/test/features/write_test.dart`:
```dart
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jjinhugi/data/providers.dart';
import 'package:jjinhugi/domain/models.dart';
import 'package:jjinhugi/domain/score.dart';
import 'package:jjinhugi/features/write/write_review_screen.dart';

import '../helpers.dart';

const p1 = PlaceResult(placeId: 'p1', name: '성수 찐국밥', address: '서울 성동구 성수동2가 300-1', region: 'seongsu');
const far = PlaceResult(placeId: 'far', name: '강남 찐돈까스', address: '서울 강남구 역삼동 100', region: null);

Restaurant rest(String id, String name) => Restaurant(id: id, name: name, address: '서울', region: 'seongsu');

XFile fakeImage() => XFile.fromData(Uint8List.fromList([1, 2, 3]), mimeType: 'image/png', name: 'r.png');

FakeBackend backend({Map<String, List<String>> ranking = const {}}) => FakeBackend()
  ..places = [p1, far]
  ..restaurants = [rest('a', '가게A'), rest('b', '가게B')]
  ..users = {'me': appUser('me', ranking: ranking)};

Widget screen(FakeBackend b, {PlaceResult? initial}) => harness(
      child: WriteReviewScreen(initialPlace: initial),
      backend: b,
      overrides: [
        imagePickerProvider.overrideWithValue(() async => fakeImage()),
        photosPickerProvider.overrideWithValue(() async => [fakeImage(), fakeImage()]),
      ],
    );

Future<void> next(WidgetTester t) async {
  await t.tap(find.text('다음'));
  await t.pumpAndSettle();
}

Future<void> pickReceipt(WidgetTester t) async {
  await t.tap(find.text('영수증 사진 선택'));
  await t.pumpAndSettle();
  expect(find.text('영수증 선택됨'), findsOneWidget);
}

Future<void> chooseTier(WidgetTester t, Tier tier) async {
  await t.tap(find.widgetWithText(ChoiceChip, tier.label));
  await t.pumpAndSettle();
}

Future<void> searchAndPick(WidgetTester t, String name) async {
  await t.enterText(find.byType(TextField), '찐');
  await t.tap(find.text('검색'));
  await t.pumpAndSettle();
  await t.tap(find.text(name));
  await t.pumpAndSettle();
}

Future<void> writeTextAndSubmit(WidgetTester t, [String text = '국물이 진하고 고기가 많아요']) async {
  await t.enterText(find.byType(TextField), text);
  await t.pumpAndSettle();
  await t.tap(find.text('제출'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('전체 흐름: 비교 후 제출하면 입력값이 계약대로 전달되고 상세로 이동', (tester) async {
    final b = backend(ranking: {'best': ['a', 'b']});
    await tester.pumpWidget(screen(b));
    await tester.pumpAndSettle();

    await searchAndPick(tester, '성수 찐국밥');
    await next(tester);
    await pickReceipt(tester);
    await next(tester);
    await chooseTier(tester, Tier.best);
    await next(tester);

    // 후보 [a, b] — 첫 질문은 가운데(b), 새 식당이 더 좋다고 두 번 답하면 맨 위
    expect(find.textContaining('가게B'), findsOneWidget);
    await tester.tap(find.text('이번 식당이 더 좋았어요'));
    await tester.pumpAndSettle();
    expect(find.textContaining('가게A'), findsOneWidget);
    await tester.tap(find.text('이번 식당이 더 좋았어요'));
    await tester.pumpAndSettle();
    expect(find.textContaining('순위가 정해졌어요'), findsOneWidget);
    await next(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('이벤트 때 준 별점'), findsOneWidget);
    await tester.tap(find.byKey(const Key('star-4')));
    await tester.pumpAndSettle();
    await next(tester);

    await tester.tap(find.text('사진 추가'));
    await tester.pumpAndSettle();
    await writeTextAndSubmit(tester);

    final s = b.lastSubmit!;
    expect(s.placeId, 'p1');
    expect(s.tier, Tier.best);
    expect(s.rankIndex, 0);
    expect(s.eventJoined, isTrue);
    expect(s.eventStars, 4);
    expect(s.text, '국물이 진하고 고기가 많아요');
    expect(s.receiptPath, 'receipts/me/0.jpg');
    expect(s.photos, ['photos/me/1.jpg', 'photos/me/2.jpg']);
    expect(find.text('detail:p1'), findsOneWidget);
  });

  testWidgets('후보에서 현재 식당 제외 (같은 식당 재방문)', (tester) async {
    final b = backend(ranking: {'best': ['p1', 'b']});
    b.restaurants = [rest('p1', '성수 찐국밥'), rest('b', '가게B')];
    await tester.pumpWidget(screen(b, initial: p1));
    await tester.pumpAndSettle();

    await pickReceipt(tester);
    await next(tester);
    await chooseTier(tester, Tier.best);
    await next(tester);

    // 후보는 [b] 하나뿐이어야 한다. 자기 자신('성수 찐국밥')과 비교하면 안 됨
    expect(find.textContaining('가게B'), findsOneWidget);
    expect(find.textContaining('비교 식당이 더 좋았어요'), findsOneWidget);
    await tester.tap(find.text('비교 식당이 더 좋았어요'));
    await tester.pumpAndSettle();
    expect(find.textContaining('순위가 정해졌어요'), findsOneWidget);
    await next(tester);
    await next(tester);
    await writeTextAndSubmit(tester);
    expect(b.lastSubmit!.rankIndex, 1);
  });

  testWidgets('같은 등급 식당이 없으면 비교 없이 위치 0', (tester) async {
    final b = backend();
    await tester.pumpWidget(screen(b, initial: p1));
    await tester.pumpAndSettle();
    await pickReceipt(tester);
    await next(tester);
    await chooseTier(tester, Tier.ok);
    await next(tester);
    expect(find.text('같은 등급에 비교할 식당이 아직 없어요'), findsOneWidget);
    await next(tester);
    await next(tester);
    await writeTextAndSubmit(tester);
    expect(b.lastSubmit!.rankIndex, 0);
    expect(b.lastSubmit!.eventJoined, isFalse);
    expect(b.lastSubmit!.eventStars, isNull);
  });

  testWidgets('베타 지역 밖 식당 선택 불가', (tester) async {
    await tester.pumpWidget(screen(backend()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '찐');
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();
    expect(find.text('베타 지역 아님'), findsOneWidget);
    await tester.tap(find.text('강남 찐돈까스'));
    await tester.pumpAndSettle();
    final nextBtn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음'));
    expect(nextBtn.onPressed, isNull);
  });

  testWidgets('단계별 필수 입력: 영수증·등급·한줄평', (tester) async {
    await tester.pumpWidget(screen(backend(), initial: p1));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음')).onPressed, isNull);
    await pickReceipt(tester);
    await next(tester);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음')).onPressed, isNull);
    await chooseTier(tester, Tier.bad);
    await next(tester);
    await next(tester);
    await next(tester);
    await tester.enterText(find.byType(TextField), '짧아요');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '제출')).onPressed, isNull);
  });

  testWidgets('제출 실패 시 입력 보존 + 이유 표시, 다시 제출 가능', (tester) async {
    final b = backend()
      ..submitError = FirebaseFunctionsException(message: 'store_mismatch', code: 'failed-precondition');
    await tester.pumpWidget(screen(b, initial: p1));
    await tester.pumpAndSettle();
    await pickReceipt(tester);
    await next(tester);
    await chooseTier(tester, Tier.ok);
    await next(tester);
    await next(tester);
    await next(tester);
    await writeTextAndSubmit(tester, '무난하게 먹기 좋았어요 괜찮음');

    expect(find.textContaining('영수증의 가게가 선택한 식당과 달라요'), findsOneWidget);
    expect(find.text('무난하게 먹기 좋았어요 괜찮음'), findsOneWidget); // 입력 유지
    expect(find.text('detail:p1'), findsNothing);

    b.submitError = null;
    await tester.tap(find.text('제출'));
    await tester.pumpAndSettle();
    expect(b.lastSubmit!.text, '무난하게 먹기 좋았어요 괜찮음');
    expect(find.text('detail:p1'), findsOneWidget);
  });

  testWidgets('알 수 없는 예외도 기본 문구로 표시', (tester) async {
    final b = backend()..submitError = StateError('boom');
    await tester.pumpWidget(screen(b, initial: p1));
    await tester.pumpAndSettle();
    await pickReceipt(tester);
    await next(tester);
    await chooseTier(tester, Tier.ok);
    await next(tester);
    await next(tester);
    await next(tester);
    await writeTextAndSubmit(tester);
    expect(find.textContaining('알 수 없는 오류'), findsOneWidget);
  });

  testWidgets('이전 버튼으로 돌아가면 선택값 유지', (tester) async {
    await tester.pumpWidget(screen(backend(), initial: p1));
    await tester.pumpAndSettle();
    await pickReceipt(tester);
    await next(tester);
    await tester.tap(find.text('이전'));
    await tester.pumpAndSettle();
    expect(find.text('영수증 선택됨'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd app && flutter test test/features/write_test.dart`
Expected: FAIL — 임시 화면이라 `검색` 등을 찾지 못함

- [ ] **Step 3: 구현**

`app/lib/features/write/write_review_screen.dart` (전체 교체):
```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/providers.dart';
import '../../domain/errors.dart';
import '../../domain/models.dart';
import '../../domain/ranking_session.dart';
import '../../domain/score.dart';

class WriteReviewScreen extends ConsumerStatefulWidget {
  const WriteReviewScreen({super.key, this.initialPlace});
  final PlaceResult? initialPlace;

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  static const _lastStep = 5;
  static const _titles = ['식당 찾기', '영수증 인증', '어땠나요?', '순위 정하기', '리뷰 이벤트', '한줄평'];

  int _step = 0;
  PlaceResult? _place;
  List<PlaceResult> _results = [];
  final _query = TextEditingController();
  final _text = TextEditingController();
  XFile? _receipt;
  Tier? _tier;
  Map<String, Restaurant> _names = {};
  RankingSession? _session;
  bool _eventJoined = false;
  int _stars = 5;
  List<XFile> _photos = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _place = widget.initialPlace;
    _step = _place == null ? 0 : 1;
  }

  @override
  void dispose() {
    _query.dispose();
    _text.dispose();
    super.dispose();
  }

  bool get _canNext => switch (_step) {
        0 => _place != null && _place!.region != null,
        1 => _receipt != null,
        2 => _tier != null,
        3 => _session?.done ?? false,
        4 => true,
        _ => _text.text.trim().length >= 10 && _text.text.trim().length <= 300,
      };

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() => _error = null);
    try {
      final r = await ref.read(backendProvider).searchPlaces(q);
      if (mounted) setState(() => _results = r);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = reviewErrorText(e.message));
    } catch (_) {
      if (mounted) setState(() => _error = reviewErrorText(null));
    }
  }

  Future<void> _prepareCompare() async {
    final backend = ref.read(backendProvider);
    final uid = ref.read(authServiceProvider).currentUid!;
    final user = await backend.watchUser(uid).first;
    final ids = [
      for (final id in user?.ranking[_tier!] ?? const <String>[])
        if (id != _place!.placeId) id
    ];
    final names = ids.isEmpty ? <String, Restaurant>{} : await backend.getRestaurants(ids);
    _names = names;
    _session = RankingSession(ids);
  }

  Future<void> _next() async {
    if (_step == 2) await _prepareCompare();
    if (mounted) setState(() => _step++);
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final backend = ref.read(backendProvider);
    try {
      final receiptPath = await backend.uploadImage('receipts', await _receipt!.readAsBytes(), _receipt!.mimeType ?? 'image/jpeg');
      final photoPaths = <String>[];
      for (final p in _photos) {
        photoPaths.add(await backend.uploadImage('photos', await p.readAsBytes(), p.mimeType ?? 'image/jpeg'));
      }
      await backend.submitReview(SubmitInput(
        placeId: _place!.placeId,
        receiptPath: receiptPath,
        tier: _tier!,
        rankIndex: _session!.index,
        eventJoined: _eventJoined,
        eventStars: _eventJoined ? _stars : null,
        text: _text.text.trim(),
        photos: photoPaths,
      ));
      if (!mounted) return;
      context.go('/r/${_place!.placeId}');
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = reviewErrorText(e.message));
    } catch (_) {
      if (mounted) setState(() => _error = reviewErrorText(null));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.initialPlace == null ? 0 : 1;
    return Scaffold(
      appBar: AppBar(title: Text('후기 쓰기 · ${_titles[_step]}')),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_step + 1) / (_lastStep + 1)),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _page())),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_step > first)
                  OutlinedButton(
                    onPressed: _busy ? null : () => setState(() => _step--),
                    child: const Text('이전'),
                  ),
                const Spacer(),
                if (_step < _lastStep)
                  FilledButton(onPressed: _canNext && !_busy ? _next : null, child: const Text('다음'))
                else
                  FilledButton(onPressed: _canNext && !_busy ? _submit : null, child: const Text('제출')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _page() => switch (_step) {
        0 => _searchStep(),
        1 => _receiptStep(),
        2 => _tierStep(),
        3 => _compareStep(),
        4 => _eventStep(),
        _ => _textStep(),
      };

  Widget _searchStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  decoration: const InputDecoration(labelText: '식당 이름', border: OutlineInputBorder()),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _search, child: const Text('검색')),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in _results)
            ListTile(
              selected: _place?.placeId == p.placeId,
              title: Text(p.name),
              subtitle: Text(p.region == null ? '베타 지역 아님' : p.address),
              trailing: _place?.placeId == p.placeId ? const Icon(Icons.check) : null,
              onTap: () => setState(() => _place = p),
            ),
        ],
      );

  Widget _receiptStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_place?.name ?? ''} 영수증을 올려 주세요', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('방문 후 30일 이내 영수증만 인증돼요. 인증이 끝나면 영수증 원본은 30일 뒤 자동 삭제돼요.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.receipt_long),
            label: const Text('영수증 사진 선택'),
            onPressed: () async {
              final f = await ref.read(imagePickerProvider)();
              if (f != null && mounted) setState(() => _receipt = f);
            },
          ),
          if (_receipt != null) const Padding(padding: EdgeInsets.only(top: 8), child: Text('영수증 선택됨')),
        ],
      );

  Widget _tierStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_place?.name ?? ''}, 어땠나요?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('리뷰 이벤트 서비스와 상관없이, 솔직한 느낌으로 골라 주세요.'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              for (final t in Tier.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: _tier == t,
                  onSelected: (_) => setState(() {
                    _tier = t;
                    _session = null;
                  }),
                ),
            ],
          ),
        ],
      );

  Widget _compareStep() {
    final s = _session;
    if (s == null) return const SizedBox.shrink();
    if (s.candidates.isEmpty) return const Text('같은 등급에 비교할 식당이 아직 없어요');
    if (s.done) return Text('순위가 정해졌어요 (${_tier!.label} 등급 ${s.index + 1}번째)');
    final cur = s.current!;
    final curName = _names[cur]?.name ?? cur;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('"$curName"와(과) 비교해 주세요', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => s.answer(newIsBetter: true)),
          child: const Text('이번 식당이 더 좋았어요'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => setState(() => s.answer(newIsBetter: false)),
          child: const Text('비교 식당이 더 좋았어요'),
        ),
      ],
    );
  }

  Widget _eventStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('리뷰 이벤트에 참여했나요?'),
            subtitle: const Text('음료·서비스를 받고 리뷰를 쓴 적이 있다면 켜 주세요. 솔직하게 알려 주실수록 찐점수가 정확해져요.'),
            value: _eventJoined,
            onChanged: (v) => setState(() => _eventJoined = v),
          ),
          if (_eventJoined) ...[
            const SizedBox(height: 8),
            const Text('이벤트 때 준 별점'),
            Row(
              children: [
                for (var n = 1; n <= 5; n++)
                  IconButton(
                    key: Key('star-$n'),
                    icon: Icon(n <= _stars ? Icons.star : Icons.star_border),
                    onPressed: () => setState(() => _stars = n),
                  ),
              ],
            ),
          ],
        ],
      );

  Widget _textStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _text,
            maxLength: 300,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '한줄평', helperText: '10자 이상', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('사진 추가'),
            onPressed: () async {
              final picked = await ref.read(photosPickerProvider)();
              if (picked.isNotEmpty && mounted) setState(() => _photos = picked.take(5).toList());
            },
          ),
          if (_photos.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('사진 ${_photos.length}장 선택됨')),
        ],
      );
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd app && flutter test && flutter analyze`
Expected: PASS (write 8 추가, 전체 통과), `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add app/lib/features/write app/test/features/write_test.dart
git commit -m "feat(app): add write-review flow with receipt, comparison and event steps"
```

---

### Task 8: 로컬 실행 가이드와 실제 에뮬레이터 점검

**Files:**
- Create: `docs/run-local.md`

**Interfaces:**
- Consumes: Task 0~7 전체

- [ ] **Step 1: 가이드 작성**

`docs/run-local.md`:
````markdown
# 로컬에서 앱 돌려보기 (Chrome + Firebase Emulator)

키·실서버 없이 전체 흐름(로그인 → 목록 → 상세 → 후기 작성 → 따봉·신고 → 프로필)을 볼 수 있다.
카카오 검색과 영수증 OCR은 에뮬레이터에서만 **가짜**로 동작한다 (영수증은 어떤 사진이든 선택한 식당의 영수증으로 인정).

## 준비 (1회)
- Flutter SDK, Chrome, Node 22+, Java 11+ (firebase-tools 13 기준)
- 저장소 루트에서:
```powershell
npm --prefix functions install
npm --prefix functions run build
npm --prefix functions run dev:setup
cd app; flutter pub get; cd ..
```

## 실행 (터미널 3개)
```powershell
# 터미널 A — 에뮬레이터 (Auth 9099 / Functions 5001 / Firestore 8080 / Storage 9199 / UI 4000)
npm --prefix functions run emu

# 터미널 B — A가 "All emulators ready" 를 찍은 뒤, 데모 데이터 주입
npm --prefix functions run seed

# 터미널 C — 앱
cd app
flutter run -d chrome --dart-define=USE_EMULATOR=true
```
에뮬레이터 UI: http://localhost:4000 (DB·가입자 확인, `crowns`·`reports` 확인 가능)

> 함수 코드를 고치면 `npm --prefix functions run build` 후 터미널 A를 다시 띄운다. 에뮬레이터를 껐다 켜면 데이터가 사라지므로 `seed`를 다시 실행한다.

## 수동 점검 체크리스트
1. **로그인**: 닉네임(예: `내가씀`) → 테스트 로그인 → 홈으로 이동. 새로고침해도 로그인 유지.
2. **홈**: 성수 식당 4곳. `성수 찐국밥 찐 7.8`, `성수 찐고기 찐 2.3 · 이벤트 10.0 · 거품 +7.7`. `거품 큰 순`을 누르면 찐고기가 맨 위. 상단에 `👑 이번 달 찐후기 대마왕 · 찐미식가` 배너 → 누르면 그 유저 프로필.
3. **상세**: 식당 하나 → 후기 3개, 이벤트 참여 후기에 🎁 라벨. 따봉순/최신순 전환.
4. **따봉 제한**: 방금 가입한 계정으로 남의 후기 따봉 → "영수증 인증 후기를 1개 이상 쓰면…" 안내.
5. **후기 작성** (`성수 찐빵집`은 후기가 없는 식당):
   `후기 쓰기` → `찐빵` 검색 → 선택 → 아무 이미지로 영수증 선택 → 등급 `최고` → (비교 없음) → 이벤트 켜고 별 5 → 한줄평 10자 이상 → 제출.
   → 상세로 이동, 내 후기가 보임. 홈에서 `찐빵집`은 후기 3개 미만이라 `찐 데이터 부족`.
6. **따봉 가능해짐**: 5번 이후 남의 후기에 따봉 → 숫자가 오르고 (잠시 뒤) 작성자 프로필의 `받은 따봉` 증가.
7. **본인 후기 따봉 불가**: 내 후기의 따봉 버튼이 회색.
8. **중복 방지**: 같은 식당에 후기를 다시 쓰면 "재방문"으로 덮어써지고 후기 수는 그대로.
9. **베타 밖**: `찐돈까스` 검색 → `베타 지역 아님`으로 선택 불가.
10. **비교 질문**: 후기를 2~3개 더 쓰고(다른 식당, 같은 등급) 새 식당을 쓸 때 "○○와(과) 비교해 주세요" 질문이 나오고 답에 따라 내 리스트 순위가 바뀐다 (프로필 → 내 리스트).
11. **신고**: 후기의 깃발 → 사유 입력 → 에뮬레이터 UI의 `reports`에 문서 생김.
12. **로그아웃**: 내 프로필 → 로그아웃 → 로그인 화면으로 이동.

## 막힐 때
- `Your requested "node" version "22" doesn't match your global version` 오류: `functions/package.json`의 `engines.node`를 `">=22"`로 바꾼다.
- 에뮬레이터가 Java 오류로 안 뜸: `java -version` 확인 (11 이상). firebase-tools 14+ 로 올리려면 JDK 21 필요.
- 앱 화면이 비어 있음: 터미널 B(seed)를 실행했는지, 브라우저 콘솔에 `permission-denied` 가 없는지 확인.
- `FirebaseFunctionsException: INTERNAL`: 터미널 A 로그를 확인. 시크릿 관련이면 `npm --prefix functions run dev:setup` 후 에뮬레이터 재시작.
````

- [ ] **Step 2: 실제 에뮬레이터로 점검 (사람이 보는 항목은 실행자가 로그로 대체 확인)**

위 가이드대로 터미널 A·B를 띄우고, 자동으로 확인 가능한 항목만 점검한다:
```bash
npm --prefix functions run build
npm --prefix functions run dev:setup
npm --prefix functions run emu          # 터미널 A (백그라운드)
npm --prefix functions run seed         # 터미널 B
cd app && flutter build web --dart-define=USE_EMULATOR=true
```
Expected: `seeded demo data → localhost:8080`, `flutter build web` 성공. 브라우저 점검(체크리스트 1~12)은 사람이 `flutter run -d chrome --dart-define=USE_EMULATOR=true`로 확인하고, 결과를 이 플랜의 담당자에게 알린다. 실행자가 브라우저를 직접 열 수 없는 환경이면 "웹 빌드 성공, 수동 점검 대기"로 보고한다 — 점검을 했다고 쓰지 않는다.

- [ ] **Step 3: 전체 테스트와 커밋**

Run: `npm --prefix functions run test:unit && npm --prefix functions run test:emu && cd app && flutter test && flutter analyze`
Expected: 전부 통과

```bash
git add docs/run-local.md
git commit -m "docs: add local run guide and manual checklist"
```

---

## 플랜 3 예고 (이 플랜 범위 밖)

- 카카오 로그인(`kakao_flutter_sdk_user` → `kakaoLogin` 콜러블 → `signInWithCustomToken`), Apple 로그인
- 실제 Firebase 프로젝트 연결(`flutterfire configure`, `firebase_options.dart`), 실서버 배포
- 지도(네이버 지도 SDK, 모바일 전용), 현재 위치 기반 검색(`searchPlaces`에 lat/lng 전달)
- 앱 아이콘·스토어 등록, 개인정보 처리방침
