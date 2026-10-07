# 찐후기 백엔드 (플랜 1/2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 찐후기 앱이 호출할 Firebase 백엔드(점수 계산, 영수증 검증, 후기 제출, 따봉·칭호, 대마왕 선정, 로그인, 장소 검색, 보안 규칙)를 Emulator에서 전부 테스트된 상태로 만든다.

**Architecture:** 비즈니스 로직은 Firebase에 의존하지 않는 순수 함수(`scoring`, `address`, `receipt`, `title`)로 분리하고, 각 Cloud Function 파일은 `xxxCore(db, deps, ...)` 코어 함수 + 얇은 `onCall`/트리거 래퍼로 구성한다. 외부 API(CLOVA OCR, 카카오)는 `deps`로 주입해 테스트에서 가짜로 바꾼다. 클라이언트 쓰기는 따봉·신고·Storage 업로드만 허용하고 나머지는 전부 함수 경유.

**Tech Stack:** Node 22, TypeScript(strict), firebase-functions v2 API, firebase-admin, geofire-common, Jest + ts-jest, Firebase Emulator Suite, @firebase/rules-unit-testing.

**Spec:** `docs/superpowers/specs/2026-10-07-jjinhugi-design.md`

**플랜 2(Flutter 앱)** 는 이 플랜의 "앱 계약" 절(문서 끝)을 그대로 사용한다.

## Global Constraints

- Functions 리전: `asia-northeast3` (서울)
- Emulator 프로젝트 ID: `demo-jjinhugi` (demo- 접두어 → 실 프로젝트 없이 Emulator 실행)
- 점수 구간: 최고 7~10 / 괜찮 4~7 / 별로 0~4, 소수점 1자리
- 찐점수·이벤트 점수 표시 최소 후기 수: 3 (`MIN_REVIEWS = 3`)
- 영수증 유효 기간: 방문일 30일 이내 (KST 기준)
- 하루 후기 작성 제한: 5개 (KST 날짜 기준)
- 한줄평 10~300자, 사진 최대 5장
- 칭호: 찐린이(0) / 찐후기러(10+) / 찐고수(50+) / 찐후기 대마왕(월간 지역별 1위)
- 영수증 원본 30일 후 삭제
- 후기 문서 ID: `{uid}_{placeId}` (유저당 식당 1후기)
- 모든 시간 기준 날짜 계산은 KST(UTC+9)

## Review Focus

1. **도로명 주소만 찍힌 영수증** — 카카오 지번 주소와 동이 안 겹쳐도 도로명이 같으면 통과해야 함 → Task 2 `addressMatches` 테스트
2. **같은 식당 재방문 후기** — reviewCount·verifiedReviewCount가 두 번 세어지면 안 되고, 이벤트 점수는 이전 값을 빼고 새 값을 더해야 함 → Task 6 "재방문" 테스트
3. **등급 이동(최고→별로)** — 이전 등급에 남은 다른 식당들의 개인 점수와 그 식당 찐점수 합계가 같이 재계산돼야 함 → Task 6 "등급 이동" 테스트
4. **영수증 날짜 경계** — 정확히 30일 전은 통과, 31일 전·미래 날짜는 거절, KST 자정 직후 기준 → Task 2 날짜 테스트
5. **재검색 시 집계 보존** — 이미 후기가 있는 식당을 다시 검색해 upsert해도 scoreSum 등 집계 필드가 지워지면 안 됨 → Task 5 "집계 보존" 테스트

---

## 파일 구조

```
firebase.json                 Emulator·배포 설정
.firebaserc                   기본 프로젝트(demo-jjinhugi)
firestore.rules               Firestore 보안 규칙
firestore.indexes.json        복합 인덱스
storage.rules                 Storage 보안 규칙
storage-lifecycle.json        receipts/ 30일 삭제 규칙
functions/
  package.json, tsconfig.json, jest.config.js
  src/
    index.ts                  admin 초기화 + 함수 export
    config.ts                 리전, 시크릿/파라미터
    scoring.ts                개인 점수, 순위 삽입, 집계 (순수)
    address.ts                주소 파싱, 지역 판정 (순수)
    receipt.ts                영수증 검증, 해시, KST 날짜 (순수)
    title.ts                  칭호 (순수)
    ocr.ts                    CLOVA OCR 호출·파싱
    kakao.ts                  카카오 로컬 검색, 사용자 정보
    search.ts                 searchPlaces
    review.ts                 submitReview
    auth.ts                   kakaoLogin, ensureUser
    likes.ts                  onLikeWrite
    crown.ts                  monthlyCrown
  test/
    unit/                     순수 함수 테스트 (Emulator 불필요)
    emu/                      Emulator 필요 테스트
    fixtures/clova/           CLOVA 응답 샘플
```

## 사전 준비 (실행자 1회)

- Node 22, Java 11+ (Emulator 필요), `npm i -g firebase-tools`
- 실 Firebase 프로젝트·키는 Task 10 전까지 불필요

---

### Task 1: 프로젝트 골격 + 점수 계산

**Files:**
- Create: `firebase.json`, `.firebaserc`, `.gitignore`
- Create: `functions/package.json`, `functions/tsconfig.json`, `functions/jest.config.js`
- Create: `functions/src/scoring.ts`
- Test: `functions/test/unit/scoring.test.ts`

**Interfaces:**
- Produces:
  - `type Tier = 'best' | 'ok' | 'bad'`, `const TIERS: Tier[]`, `type Ranking = Record<Tier, string[]>`, `const MIN_REVIEWS = 3`
  - `round1(x: number): number`
  - `personalScore(tier: Tier, index: number, n: number): number`
  - `emptyRanking(): Ranking`
  - `scoresOf(r: Ranking): Map<string, number>`
  - `insertPlace(r: Ranking, placeId: string, tier: Tier, rankIndex: number): Ranking` (원본 불변, 다른 등급에서 제거 후 삽입, index clamp)
  - `interface ScoreChange { old: number | null; new: number }`
  - `scoreChanges(before: Ranking, after: Ranking): Map<string, ScoreChange>` (점수가 바뀐 항목만)
  - `interface RestaurantSums { scoreSum; reviewCount; eventStarSum; eventReviewCount }` (모두 number)
  - `interface DerivedScores { realScore: number | null; eventScore: number | null; bubble: number | null }`
  - `deriveScores(s: RestaurantSums): DerivedScores`

- [ ] **Step 1: 골격 파일 작성**

`firebase.json`:
```json
{
  "functions": [{ "source": "functions", "codebase": "default", "predeploy": ["npm --prefix \"$RESOURCE_DIR\" run build"] }],
  "firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" },
  "storage": { "rules": "storage.rules" },
  "emulators": {
    "auth": { "port": 9099 },
    "functions": { "port": 5001 },
    "firestore": { "port": 8080 },
    "storage": { "port": 9199 },
    "ui": { "enabled": true }
  }
}
```

`.firebaserc`:
```json
{ "projects": { "default": "demo-jjinhugi" } }
```

`.gitignore`:
```
node_modules/
functions/lib/
*.log
.firebase/
```

`functions/package.json`:
```json
{
  "name": "functions",
  "private": true,
  "main": "lib/index.js",
  "engines": { "node": "22" },
  "scripts": {
    "build": "tsc",
    "test:unit": "jest test/unit",
    "test:emu": "cd .. && firebase emulators:exec --project demo-jjinhugi --only auth,firestore,storage \"npm --prefix functions run jest:emu\"",
    "jest:emu": "jest test/emu --runInBand"
  }
}
```

`functions/tsconfig.json`:
```json
{
  "compilerOptions": {
    "module": "commonjs",
    "target": "es2022",
    "outDir": "lib",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "sourceMap": true
  },
  "include": ["src"]
}
```

`functions/jest.config.js`:
```js
module.exports = { preset: 'ts-jest', testEnvironment: 'node', testMatch: ['**/test/**/*.test.ts'] };
```

- [ ] **Step 2: 의존성 설치**

Run:
```bash
cd functions
npm i firebase-admin firebase-functions geofire-common
npm i -D typescript jest ts-jest @types/jest @types/node @firebase/rules-unit-testing firebase
```
Expected: `node_modules` 생성, 에러 없음.

- [ ] **Step 3: 실패하는 테스트 작성**

`functions/test/unit/scoring.test.ts`:
```ts
import { personalScore, insertPlace, emptyRanking, scoreChanges, deriveScores, scoresOf } from '../../src/scoring';

describe('personalScore', () => {
  test('등급에 혼자면 구간 중앙', () => {
    expect(personalScore('best', 0, 1)).toBe(8.5);
    expect(personalScore('ok', 0, 1)).toBe(5.5);
    expect(personalScore('bad', 0, 1)).toBe(2);
  });
  test('두 개면 위아래로 나뉨 (소수 1자리 반올림)', () => {
    expect(personalScore('best', 0, 2)).toBe(9.3);
    expect(personalScore('best', 1, 2)).toBe(7.8);
  });
});

describe('insertPlace', () => {
  test('지정 위치에 삽입, 원본 불변', () => {
    const r = { best: ['a', 'b'], ok: [], bad: [] };
    const next = insertPlace(r, 'x', 'best', 1);
    expect(next.best).toEqual(['a', 'x', 'b']);
    expect(r.best).toEqual(['a', 'b']);
  });
  test('다른 등급에 있으면 옮김', () => {
    const r = { best: ['a', 'x'], ok: ['c'], bad: [] };
    expect(insertPlace(r, 'x', 'bad', 0)).toEqual({ best: ['a'], ok: ['c'], bad: ['x'] });
  });
  test('index 범위 밖은 clamp', () => {
    expect(insertPlace(emptyRanking(), 'x', 'ok', 99).ok).toEqual(['x']);
    expect(insertPlace({ best: [], ok: ['a'], bad: [] }, 'x', 'ok', -3).ok).toEqual(['x', 'a']);
  });
});

describe('scoreChanges', () => {
  test('새 식당을 최고 1위로 넣으면 기존 식당 점수 하락', () => {
    const before = { best: ['a'], ok: [], bad: [] };
    const after = insertPlace(before, 'x', 'best', 0);
    const c = scoreChanges(before, after);
    expect(c.get('x')).toEqual({ old: null, new: 9.3 });
    expect(c.get('a')).toEqual({ old: 8.5, new: 7.8 });
  });
  test('점수 안 바뀐 항목은 제외', () => {
    const before = { best: ['a'], ok: ['b'], bad: [] };
    const after = insertPlace(before, 'x', 'bad', 0);
    expect([...scoreChanges(before, after).keys()]).toEqual(['x']);
  });
  test('scoresOf는 전 등급 포함', () => {
    expect(scoresOf({ best: ['a'], ok: ['b'], bad: ['c'] })).toEqual(new Map([['a', 8.5], ['b', 5.5], ['c', 2]]));
  });
});

describe('deriveScores', () => {
  test('후기 3개 미만이면 null', () => {
    expect(deriveScores({ scoreSum: 17, reviewCount: 2, eventStarSum: 10, eventReviewCount: 2 }))
      .toEqual({ realScore: null, eventScore: null, bubble: null });
  });
  test('찐점수·이벤트점수·거품지수', () => {
    expect(deriveScores({ scoreSum: 18, reviewCount: 3, eventStarSum: 15, eventReviewCount: 3 }))
      .toEqual({ realScore: 6, eventScore: 10, bubble: 4 });
  });
  test('이벤트 후기만 부족하면 거품지수 null', () => {
    expect(deriveScores({ scoreSum: 18, reviewCount: 3, eventStarSum: 10, eventReviewCount: 2 }))
      .toEqual({ realScore: 6, eventScore: null, bubble: null });
  });
});
```

- [ ] **Step 4: 실패 확인**

Run: `cd functions && npm run test:unit`
Expected: FAIL — `Cannot find module '../../src/scoring'`

- [ ] **Step 5: 구현**

`functions/src/scoring.ts`:
```ts
export type Tier = 'best' | 'ok' | 'bad';
export const TIERS: Tier[] = ['best', 'ok', 'bad'];
export type Ranking = Record<Tier, string[]>;
export const MIN_REVIEWS = 3;

const TIER_RANGE: Record<Tier, [number, number]> = { best: [7, 10], ok: [4, 7], bad: [0, 4] };

export const round1 = (x: number): number => Math.round(x * 10) / 10;

export function personalScore(tier: Tier, index: number, n: number): number {
  const [lo, hi] = TIER_RANGE[tier];
  return round1(hi - ((hi - lo) * (index + 0.5)) / n);
}

export function emptyRanking(): Ranking {
  return { best: [], ok: [], bad: [] };
}

export function scoresOf(r: Ranking): Map<string, number> {
  const m = new Map<string, number>();
  for (const t of TIERS) r[t].forEach((id, i) => m.set(id, personalScore(t, i, r[t].length)));
  return m;
}

export function insertPlace(r: Ranking, placeId: string, tier: Tier, rankIndex: number): Ranking {
  const next = emptyRanking();
  for (const t of TIERS) next[t] = r[t].filter((id) => id !== placeId);
  const i = Math.max(0, Math.min(Math.trunc(rankIndex), next[tier].length));
  next[tier].splice(i, 0, placeId);
  return next;
}

export interface ScoreChange { old: number | null; new: number }

export function scoreChanges(before: Ranking, after: Ranking): Map<string, ScoreChange> {
  const a = scoresOf(before);
  const out = new Map<string, ScoreChange>();
  for (const [id, s] of scoresOf(after)) {
    const old = a.get(id) ?? null;
    if (old !== s) out.set(id, { old, new: s });
  }
  return out;
}

export interface RestaurantSums { scoreSum: number; reviewCount: number; eventStarSum: number; eventReviewCount: number }
export interface DerivedScores { realScore: number | null; eventScore: number | null; bubble: number | null }

export function deriveScores(s: RestaurantSums): DerivedScores {
  const realScore = s.reviewCount >= MIN_REVIEWS ? round1(s.scoreSum / s.reviewCount) : null;
  const eventScore = s.eventReviewCount >= MIN_REVIEWS ? round1((s.eventStarSum / s.eventReviewCount) * 2) : null;
  const bubble = realScore !== null && eventScore !== null ? round1(eventScore - realScore) : null;
  return { realScore, eventScore, bubble };
}
```

- [ ] **Step 6: 통과 확인**

Run: `cd functions && npm run test:unit`
Expected: PASS (11 tests)

- [ ] **Step 7: 커밋**

```bash
git add firebase.json .firebaserc .gitignore functions/package.json functions/package-lock.json functions/tsconfig.json functions/jest.config.js functions/src/scoring.ts functions/test/unit/scoring.test.ts
git commit -m "feat(functions): scaffold Firebase project and scoring functions"
```

---

### Task 2: 주소 파싱 + 영수증 검증

**Files:**
- Create: `functions/src/address.ts`, `functions/src/receipt.ts`
- Test: `functions/test/unit/address.test.ts`, `functions/test/unit/receipt.test.ts`

**Interfaces:**
- Produces (`address.ts`):
  - `interface AddressParts { gu: string | null; dong: string | null; road: string | null }` — dong은 숫자·"동" 제거한 기본형 (`성수동2가`→`성수`)
  - `addressParts(addr: string): AddressParts`
  - `interface Region { id: string; name: string; gu: string; dongs: string[] }`
  - `regionFor(address: string, regions: Region[]): string | null`
- Produces (`receipt.ts`):
  - `interface OcrReceipt { storeName: string | null; address: string | null; date: string | null /* YYYY-MM-DD */; total: number | null; approvalNo: string | null }`
  - `interface PlaceInfo { name: string; address: string; roadAddress: string }`
  - `type ReceiptFailure = 'unreadable' | 'store_mismatch' | 'date_expired'`
  - `type ReceiptResult = { ok: true; hash: string; visitDate: string } | { ok: false; reason: ReceiptFailure }`
  - `MAX_RECEIPT_AGE_DAYS = 30`
  - `kstDate(now: Date): string` (YYYY-MM-DD)
  - `normalizeName(s: string): string`, `nameMatches(ocr: string, place: string): boolean`
  - `addressMatches(ocrAddr: string, place: PlaceInfo): boolean`
  - `receiptHash(approvalNo: string, total: number, date: string): string` (sha256 hex)
  - `verifyReceipt(r: OcrReceipt, place: PlaceInfo, now: Date): ReceiptResult`

- [ ] **Step 1: 실패하는 테스트 작성**

`functions/test/unit/address.test.ts`:
```ts
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
```

`functions/test/unit/receipt.test.ts`:
```ts
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
```

- [ ] **Step 2: 실패 확인**

Run: `cd functions && npm run test:unit`
Expected: FAIL — `Cannot find module '../../src/address'`

- [ ] **Step 3: 구현**

`functions/src/address.ts`:
```ts
export interface AddressParts { gu: string | null; dong: string | null; road: string | null }
export interface Region { id: string; name: string; gu: string; dongs: string[] }

// ponytail: "구"가 있는 주소만 지원 (베타는 서울 한정). 구 없는 시(경기 광주시 등) 확장 시 시/군 토큰 추가.
export function addressParts(addr: string): AddressParts {
  const tokens = addr.trim().split(/\s+/);
  const gu = tokens.find((t) => /^[가-힣]+구$/.test(t)) ?? null;
  const road = tokens.find((t) => /^[가-힣][가-힣\d]*(로|길)$/.test(t)) ?? null;
  const dongTok = tokens.find((t) => /^[가-힣][가-힣\d]*(동|가)$/.test(t)) ?? null;
  const dong = dongTok ? dongTok.replace(/\d.*$/, '').replace(/동$/, '') : null;
  return { gu, dong, road };
}

export function regionFor(address: string, regions: Region[]): string | null {
  const p = addressParts(address);
  return regions.find((r) => r.gu === p.gu && p.dong !== null && r.dongs.includes(p.dong))?.id ?? null;
}
```

`functions/src/receipt.ts`:
```ts
import { createHash } from 'node:crypto';
import { addressParts } from './address';

export interface OcrReceipt { storeName: string | null; address: string | null; date: string | null; total: number | null; approvalNo: string | null }
export interface PlaceInfo { name: string; address: string; roadAddress: string }
export type ReceiptFailure = 'unreadable' | 'store_mismatch' | 'date_expired';
export type ReceiptResult = { ok: true; hash: string; visitDate: string } | { ok: false; reason: ReceiptFailure };

export const MAX_RECEIPT_AGE_DAYS = 30;
const DAY_MS = 86_400_000;

export function kstDate(now: Date): string {
  return new Date(now.getTime() + 9 * 3_600_000).toISOString().slice(0, 10);
}

export function normalizeName(s: string): string {
  return s.replace(/\(주\)|㈜|주식회사/g, '').replace(/[^0-9a-zA-Z가-힣]/g, '').toLowerCase();
}

function levenshtein(a: string, b: string): number {
  let prev = Array.from({ length: b.length + 1 }, (_, j) => j);
  for (let i = 1; i <= a.length; i++) {
    const cur = [i];
    for (let j = 1; j <= b.length; j++) {
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    }
    prev = cur;
  }
  return prev[b.length];
}

export function nameMatches(ocrName: string, placeName: string): boolean {
  const a = normalizeName(ocrName);
  const b = normalizeName(placeName);
  if (!a || !b) return false;
  if (Math.min(a.length, b.length) >= 2 && (a.includes(b) || b.includes(a))) return true;
  return levenshtein(a, b) <= Math.max(1, Math.floor(Math.max(a.length, b.length) * 0.2));
}

export function addressMatches(ocrAddr: string, place: PlaceInfo): boolean {
  const o = addressParts(ocrAddr);
  const jibun = addressParts(place.address);
  const road = addressParts(place.roadAddress);
  if (!o.gu || (o.gu !== jibun.gu && o.gu !== road.gu)) return false;
  return (o.dong !== null && o.dong === jibun.dong) || (o.road !== null && o.road === road.road);
}

export function receiptHash(approvalNo: string, total: number, date: string): string {
  return createHash('sha256').update(`${approvalNo}|${total}|${date}`).digest('hex');
}

export function verifyReceipt(r: OcrReceipt, place: PlaceInfo, now: Date): ReceiptResult {
  if (!r.storeName || !r.address || !r.date || r.total === null || !r.approvalNo) return { ok: false, reason: 'unreadable' };
  if (!nameMatches(r.storeName, place.name) || !addressMatches(r.address, place)) return { ok: false, reason: 'store_mismatch' };
  const age = Math.round((Date.parse(kstDate(now)) - Date.parse(r.date)) / DAY_MS);
  if (Number.isNaN(age) || age < 0 || age > MAX_RECEIPT_AGE_DAYS) return { ok: false, reason: 'date_expired' };
  return { ok: true, hash: receiptHash(r.approvalNo, r.total, r.date), visitDate: r.date };
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd functions && npm run test:unit`
Expected: PASS (scoring 11 + address 4 + receipt 16)

- [ ] **Step 5: 커밋**

```bash
git add functions/src/address.ts functions/src/receipt.ts functions/test/unit/address.test.ts functions/test/unit/receipt.test.ts
git commit -m "feat(functions): add address parsing and receipt verification"
```

---

### Task 3: CLOVA OCR · 카카오 어댑터

**Files:**
- Create: `functions/src/ocr.ts`, `functions/src/kakao.ts`
- Create: `functions/test/fixtures/clova/cases.json`, `functions/test/fixtures/clova/sample-ok.json`
- Test: `functions/test/unit/ocr.test.ts`, `functions/test/unit/kakao.test.ts`

**Interfaces:**
- Consumes: `OcrReceipt` (Task 2)
- Produces (`ocr.ts`):
  - `interface ClovaConfig { url: string; secret: string }`
  - `parseClovaReceipt(json: unknown): OcrReceipt`
  - `clovaOcr(image: Buffer, cfg: ClovaConfig, fetchFn?: typeof fetch): Promise<OcrReceipt>` — HTTP 실패 시 `Error` throw
- Produces (`kakao.ts`):
  - `interface LatLng { lat: number; lng: number }`
  - `interface KakaoPlace { placeId: string; name: string; address: string; roadAddress: string; lat: number; lng: number }`
  - `parseKakaoKeyword(json: unknown): KakaoPlace[]` (음식점 FD6·카페 CE7만)
  - `kakaoKeywordSearch(query: string, near: LatLng | null, restKey: string, fetchFn?: typeof fetch): Promise<KakaoPlace[]>`
  - `interface KakaoProfile { id: string; nickname: string | null }`
  - `kakaoMe(accessToken: string, fetchFn?: typeof fetch): Promise<KakaoProfile>`

- [ ] **Step 1: CLOVA 응답 구조 확인**

NAVER Cloud Platform 문서 "CLOVA OCR > Receipt OCR" 응답 예시를 열어 아래 경로가 실제와 같은지 대조한다. 다르면 Step 2 fixture와 Step 5 `parseClovaReceipt`의 경로를 **둘 다** 실제 구조로 고친다.
- 상호명: `images[0].receipt.result.storeInfo.name.formatted.value`
- 주소: `images[0].receipt.result.storeInfo.addresses[0].formatted.value`
- 날짜: `images[0].receipt.result.paymentInfo.date.formatted.{year,month,day}`
- 승인번호: `images[0].receipt.result.paymentInfo.confirmNum.text`
- 합계: `images[0].receipt.result.totalPrice.price.formatted.value`

- [ ] **Step 2: fixture 작성**

`functions/test/fixtures/clova/sample-ok.json`:
```json
{
  "version": "V2",
  "requestId": "r1",
  "timestamp": 0,
  "images": [{
    "uid": "u1",
    "name": "receipt",
    "inferResult": "SUCCESS",
    "message": "SUCCESS",
    "receipt": {
      "meta": { "estimatedLanguage": "ko" },
      "result": {
        "storeInfo": {
          "name": { "text": "성수찐국밥", "formatted": { "value": "성수찐국밥" } },
          "addresses": [{ "text": "서울 성동구 연무장길 10", "formatted": { "value": "서울 성동구 연무장길 10" } }]
        },
        "paymentInfo": {
          "date": { "text": "26.10.06", "formatted": { "year": "26", "month": "10", "day": "6" } },
          "confirmNum": { "text": "1234-5678" }
        },
        "totalPrice": { "price": { "text": "18,000", "formatted": { "value": "18000" } } }
      }
    }
  }]
}
```

`functions/test/fixtures/clova/cases.json` (실제 영수증 결과는 나중에 이 목록에 추가):
```json
[
  {
    "file": "sample-ok.json",
    "expected": { "storeName": "성수찐국밥", "address": "서울 성동구 연무장길 10", "date": "2026-10-06", "total": 18000, "approvalNo": "12345678" }
  }
]
```

- [ ] **Step 3: 실패하는 테스트 작성**

`functions/test/unit/ocr.test.ts`:
```ts
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { parseClovaReceipt, clovaOcr } from '../../src/ocr';

const dir = resolve(__dirname, '../fixtures/clova');
const cases: { file: string; expected: unknown }[] = JSON.parse(readFileSync(resolve(dir, 'cases.json'), 'utf8'));

test.each(cases)('fixture $file 파싱', ({ file, expected }) => {
  expect(parseClovaReceipt(JSON.parse(readFileSync(resolve(dir, file), 'utf8')))).toEqual(expected);
});

test('인식 실패 응답은 전부 null', () => {
  expect(parseClovaReceipt({ images: [{ inferResult: 'FAILURE' }] }))
    .toEqual({ storeName: null, address: null, date: null, total: null, approvalNo: null });
});

test('clovaOcr는 시크릿 헤더와 base64 이미지를 보냄', async () => {
  const body = JSON.parse(readFileSync(resolve(dir, 'sample-ok.json'), 'utf8'));
  const fetchFn = jest.fn().mockResolvedValue({ ok: true, json: async () => body });
  const r = await clovaOcr(Buffer.from('img'), { url: 'https://ocr.example', secret: 's3' }, fetchFn as unknown as typeof fetch);
  expect(r.storeName).toBe('성수찐국밥');
  const [url, init] = fetchFn.mock.calls[0];
  expect(url).toBe('https://ocr.example');
  expect(init.headers['X-OCR-SECRET']).toBe('s3');
  expect(JSON.parse(init.body).images[0].data).toBe(Buffer.from('img').toString('base64'));
});

test('clovaOcr HTTP 실패는 throw', async () => {
  const fetchFn = jest.fn().mockResolvedValue({ ok: false, status: 500 });
  await expect(clovaOcr(Buffer.from('x'), { url: 'u', secret: 's' }, fetchFn as unknown as typeof fetch)).rejects.toThrow('clova 500');
});
```

`functions/test/unit/kakao.test.ts`:
```ts
import { parseKakaoKeyword, kakaoKeywordSearch, kakaoMe } from '../../src/kakao';

const body = {
  documents: [
    { id: '111', place_name: '성수 찐국밥', address_name: '서울 성동구 성수동2가 300-1', road_address_name: '서울 성동구 연무장길 10', x: '127.05', y: '37.54', category_group_code: 'FD6' },
    { id: '222', place_name: '찐카페', address_name: '서울 성동구 성수동1가 1', road_address_name: '', x: '127.04', y: '37.55', category_group_code: 'CE7' },
    { id: '333', place_name: '찐주차장', address_name: '서울 성동구 성수동1가 2', road_address_name: '', x: '127.0', y: '37.5', category_group_code: 'PK6' },
  ],
};

test('음식점·카페만 남기고 숫자 변환', () => {
  expect(parseKakaoKeyword(body)).toEqual([
    { placeId: '111', name: '성수 찐국밥', address: '서울 성동구 성수동2가 300-1', roadAddress: '서울 성동구 연무장길 10', lat: 37.54, lng: 127.05 },
    { placeId: '222', name: '찐카페', address: '서울 성동구 성수동1가 1', roadAddress: '', lat: 37.55, lng: 127.04 },
  ]);
});

test('위치 있으면 x/y/radius 포함, KakaoAK 헤더', async () => {
  const fetchFn = jest.fn().mockResolvedValue({ ok: true, json: async () => body });
  await kakaoKeywordSearch('국밥', { lat: 37.5, lng: 127.0 }, 'KEY', fetchFn as unknown as typeof fetch);
  const [url, init] = fetchFn.mock.calls[0];
  const u = new URL(url);
  expect(u.searchParams.get('query')).toBe('국밥');
  expect(u.searchParams.get('x')).toBe('127');
  expect(u.searchParams.get('y')).toBe('37.5');
  expect(init.headers.Authorization).toBe('KakaoAK KEY');
});

test('kakaoMe는 id 문자열과 닉네임 반환', async () => {
  const fetchFn = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ id: 42, kakao_account: { profile: { nickname: '찐이' } } }) });
  expect(await kakaoMe('tok', fetchFn as unknown as typeof fetch)).toEqual({ id: '42', nickname: '찐이' });
  expect(fetchFn.mock.calls[0][1].headers.Authorization).toBe('Bearer tok');
});

test('kakaoMe 401은 throw', async () => {
  const fetchFn = jest.fn().mockResolvedValue({ ok: false, status: 401 });
  await expect(kakaoMe('bad', fetchFn as unknown as typeof fetch)).rejects.toThrow('kakao_me 401');
});
```

- [ ] **Step 4: 실패 확인**

Run: `cd functions && npm run test:unit`
Expected: FAIL — `Cannot find module '../../src/ocr'`

- [ ] **Step 5: 구현**

`functions/src/ocr.ts`:
```ts
import { randomUUID } from 'node:crypto';
import { OcrReceipt } from './receipt';

export interface ClovaConfig { url: string; secret: string }

const EMPTY: OcrReceipt = { storeName: null, address: null, date: null, total: null, approvalNo: null };

/* eslint-disable @typescript-eslint/no-explicit-any */
export function parseClovaReceipt(json: unknown): OcrReceipt {
  const img = (json as any)?.images?.[0];
  if (img?.inferResult !== 'SUCCESS') return { ...EMPTY };
  const r = img.receipt?.result ?? {};
  const name = r.storeInfo?.name?.formatted?.value ?? r.storeInfo?.name?.text ?? null;
  const addr = r.storeInfo?.addresses?.[0];
  const address = addr?.formatted?.value ?? addr?.text ?? null;
  const d = r.paymentInfo?.date?.formatted;
  const year = d?.year?.length === 2 ? `20${d.year}` : d?.year;
  const date = year && d?.month && d?.day ? `${year}-${d.month.padStart(2, '0')}-${d.day.padStart(2, '0')}` : null;
  const totalStr: string | undefined = r.totalPrice?.price?.formatted?.value;
  const total = totalStr && /^\d+$/.test(totalStr) ? Number(totalStr) : null;
  const approvalNo = String(r.paymentInfo?.confirmNum?.text ?? '').replace(/\D/g, '') || null;
  return { storeName: name, address, date, total, approvalNo };
}

export async function clovaOcr(image: Buffer, cfg: ClovaConfig, fetchFn: typeof fetch = fetch): Promise<OcrReceipt> {
  const res = await fetchFn(cfg.url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-OCR-SECRET': cfg.secret },
    body: JSON.stringify({
      version: 'V2',
      requestId: randomUUID(),
      timestamp: Date.now(),
      images: [{ format: 'jpg', name: 'receipt', data: image.toString('base64') }],
    }),
    signal: AbortSignal.timeout(20_000),
  });
  if (!res.ok) throw new Error(`clova ${res.status}`);
  return parseClovaReceipt(await res.json());
}
```

`functions/src/kakao.ts`:
```ts
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
```

- [ ] **Step 6: 통과 확인**

Run: `cd functions && npm run test:unit`
Expected: PASS (ocr 4 + kakao 4 추가)

- [ ] **Step 7: 커밋**

```bash
git add functions/src/ocr.ts functions/src/kakao.ts functions/test/fixtures functions/test/unit/ocr.test.ts functions/test/unit/kakao.test.ts
git commit -m "feat(functions): add CLOVA OCR and Kakao API adapters"
```

- [ ] **Step 8 (사람 작업, 블로킹 아님): 실제 영수증 fixture 추가**

CLOVA 키를 받은 뒤 베타 지역 실제 영수증 10장을 OCR 돌려 응답 JSON을 `test/fixtures/clova/real-XX.json`으로 저장하고, 사람이 눈으로 확인한 정답을 `cases.json`에 추가한다. `npm run test:unit` 실패 시 `parseClovaReceipt`를 고친다. 카드번호 등 개인정보는 fixture에서 지운다.

---

### Task 4: 보안 규칙 + 인덱스

**Files:**
- Create: `firestore.rules`, `storage.rules`, `firestore.indexes.json`
- Create: `functions/test/emu/rules.test.ts`

**Interfaces:**
- Produces: 클라이언트 권한 — 로그인 유저는 `restaurants`, `reviews`, `reviews/*/likes`, `users`, `crowns` 읽기 / 따봉 생성·삭제(조건부) / `reports` 생성 / `receipts/{uid}/*`·`photos/{uid}/*` 업로드 / `photos` 공개 읽기. 그 외 전부 거부.

- [ ] **Step 1: 실패하는 테스트 작성**

`functions/test/emu/rules.test.ts`:
```ts
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { initializeTestEnvironment, assertFails, assertSucceeds, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, serverTimestamp } from 'firebase/firestore';
import { ref, uploadBytes, getBytes } from 'firebase/storage';

const root = resolve(__dirname, '../../..');
let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-jjinhugi',
    firestore: { rules: readFileSync(resolve(root, 'firestore.rules'), 'utf8') },
    storage: { rules: readFileSync(resolve(root, 'storage.rules'), 'utf8') },
  });
});
afterAll(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/alice'), { verifiedReviewCount: 1 });
    await setDoc(doc(db, 'users/bob'), { verifiedReviewCount: 0 });
    await setDoc(doc(db, 'reviews/carol_p1'), { uid: 'carol' });
    await setDoc(doc(db, 'reviews/alice_p1'), { uid: 'alice' });
    await setDoc(doc(db, 'restaurants/p1'), { name: '찐국밥' });
    await setDoc(doc(db, 'receiptKeys/h1'), { uid: 'alice' });
    await setDoc(doc(db, 'config/regions'), { list: [] });
  });
});

const fs = (uid?: string) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const st = (uid?: string) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).storage();
const img = new Uint8Array([1, 2, 3]);

describe('따봉', () => {
  test('인증 후기 보유자는 남의 후기에 따봉 가능', () =>
    assertSucceeds(setDoc(doc(fs('alice'), 'reviews/carol_p1/likes/alice'), { createdAt: serverTimestamp() })));
  test('인증 후기 없으면 불가', () =>
    assertFails(setDoc(doc(fs('bob'), 'reviews/carol_p1/likes/bob'), { createdAt: serverTimestamp() })));
  test('본인 후기는 불가', () =>
    assertFails(setDoc(doc(fs('alice'), 'reviews/alice_p1/likes/alice'), { createdAt: serverTimestamp() })));
  test('남의 uid로는 불가', () =>
    assertFails(setDoc(doc(fs('alice'), 'reviews/carol_p1/likes/bob'), { createdAt: serverTimestamp() })));
  test('추가 필드 불가', () =>
    assertFails(setDoc(doc(fs('alice'), 'reviews/carol_p1/likes/alice'), { createdAt: serverTimestamp(), x: 1 })));
  test('없는 후기는 불가', () =>
    assertFails(setDoc(doc(fs('alice'), 'reviews/nope/likes/alice'), { createdAt: serverTimestamp() })));
  test('본인 따봉만 취소', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'reviews/carol_p1/likes/alice'), { createdAt: new Date() }));
    await assertFails(deleteDoc(doc(fs('bob'), 'reviews/carol_p1/likes/alice')));
    await assertSucceeds(deleteDoc(doc(fs('alice'), 'reviews/carol_p1/likes/alice')));
  });
});

describe('읽기·쓰기 범위', () => {
  test('로그인 유저는 식당·후기·유저 읽기', async () => {
    await assertSucceeds(getDoc(doc(fs('bob'), 'restaurants/p1')));
    await assertSucceeds(getDoc(doc(fs('bob'), 'reviews/carol_p1')));
    await assertSucceeds(getDoc(doc(fs('bob'), 'users/alice')));
  });
  test('비로그인은 읽기 불가', () => assertFails(getDoc(doc(fs(), 'restaurants/p1'))));
  test('후기·식당 직접 쓰기 불가', async () => {
    await assertFails(setDoc(doc(fs('alice'), 'reviews/alice_p2'), { uid: 'alice' }));
    await assertFails(setDoc(doc(fs('alice'), 'restaurants/p1'), { realScore: 10 }));
    await assertFails(setDoc(doc(fs('alice'), 'users/alice'), { verifiedReviewCount: 99 }));
  });
  test('receiptKeys·config 읽기 불가', async () => {
    await assertFails(getDoc(doc(fs('alice'), 'receiptKeys/h1')));
    await assertFails(getDoc(doc(fs('alice'), 'config/regions')));
  });
  test('신고는 본인 명의로만', async () => {
    await assertSucceeds(setDoc(doc(fs('bob'), 'reports/r1'), { reviewId: 'carol_p1', reporterUid: 'bob', reason: '광고', createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(fs('bob'), 'reports/r2'), { reviewId: 'carol_p1', reporterUid: 'alice', reason: '광고', createdAt: serverTimestamp() }));
  });
});

describe('Storage', () => {
  test('본인 폴더에 영수증 업로드 가능, 읽기는 본인도 불가', async () => {
    await assertSucceeds(uploadBytes(ref(st('alice'), 'receipts/alice/r1.jpg'), img, { contentType: 'image/jpeg' }));
    await assertFails(getBytes(ref(st('alice'), 'receipts/alice/r1.jpg')));
  });
  test('남의 폴더 업로드 불가', () =>
    assertFails(uploadBytes(ref(st('alice'), 'receipts/bob/r1.jpg'), img, { contentType: 'image/jpeg' })));
  test('이미지 아닌 파일 불가', () =>
    assertFails(uploadBytes(ref(st('alice'), 'photos/alice/a.txt'), img, { contentType: 'text/plain' })));
  test('사진은 비로그인도 읽기 가능', async () => {
    await env.withSecurityRulesDisabled((ctx) => uploadBytes(ref(ctx.storage(), 'photos/alice/p.jpg'), img, { contentType: 'image/jpeg' }));
    await assertSucceeds(getBytes(ref(st(), 'photos/alice/p.jpg')));
  });
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd functions && npm run test:emu`
Expected: FAIL — rules 파일 없음 (`ENOENT ... firestore.rules`)

- [ ] **Step 3: 규칙 작성**

`firestore.rules`:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() { return request.auth != null; }

    match /restaurants/{id} { allow read: if signedIn(); }
    match /users/{uid} { allow read: if signedIn(); }
    match /crowns/{id} { allow read: if signedIn(); }

    match /reviews/{reviewId} {
      allow read: if signedIn();

      match /likes/{likerUid} {
        allow read: if signedIn();
        allow create: if signedIn()
          && likerUid == request.auth.uid
          && request.resource.data.keys().hasOnly(['createdAt'])
          && request.resource.data.createdAt == request.time
          && get(/databases/$(database)/documents/reviews/$(reviewId)).data.uid != request.auth.uid
          && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.verifiedReviewCount >= 1;
        allow delete: if signedIn() && likerUid == request.auth.uid;
      }
    }

    match /reports/{id} {
      allow create: if signedIn()
        && request.resource.data.keys().hasOnly(['reviewId', 'reporterUid', 'reason', 'createdAt'])
        && request.resource.data.reporterUid == request.auth.uid
        && request.resource.data.reason is string
        && request.resource.data.reason.size() <= 200;
    }
  }
}
```

`storage.rules`:
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function validImage() {
      return request.resource.size < 10 * 1024 * 1024
        && request.resource.contentType.matches('image/.*');
    }
    match /receipts/{uid}/{file} {
      allow create: if request.auth != null && request.auth.uid == uid && validImage();
    }
    match /photos/{uid}/{file} {
      allow read: if true;
      allow create: if request.auth != null && request.auth.uid == uid && validImage();
    }
  }
}
```

`firestore.indexes.json`:
```json
{
  "indexes": [
    { "collectionGroup": "likeMonths", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "month", "order": "ASCENDING" }, { "fieldPath": "region", "order": "ASCENDING" }, { "fieldPath": "likes", "order": "DESCENDING" } ] },
    { "collectionGroup": "reviews", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "restaurantId", "order": "ASCENDING" }, { "fieldPath": "likeCount", "order": "DESCENDING" } ] },
    { "collectionGroup": "reviews", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "restaurantId", "order": "ASCENDING" }, { "fieldPath": "createdAt", "order": "DESCENDING" } ] },
    { "collectionGroup": "restaurants", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "region", "order": "ASCENDING" }, { "fieldPath": "realScore", "order": "DESCENDING" } ] },
    { "collectionGroup": "restaurants", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "region", "order": "ASCENDING" }, { "fieldPath": "bubble", "order": "DESCENDING" } ] }
  ],
  "fieldOverrides": []
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd functions && npm run test:emu`
Expected: PASS (rules 16 tests)

- [ ] **Step 5: 커밋**

```bash
git add firestore.rules storage.rules firestore.indexes.json functions/test/emu/rules.test.ts
git commit -m "feat: add Firestore/Storage security rules and indexes"
```

---

### Task 5: searchPlaces (장소 검색 + 캐시 + 식당 upsert)

**Files:**
- Create: `functions/src/config.ts`, `functions/src/search.ts`, `functions/src/index.ts`
- Create: `functions/test/emu/helpers.ts`
- Test: `functions/test/emu/search.test.ts`

**Interfaces:**
- Consumes: `KakaoPlace`, `LatLng`, `kakaoKeywordSearch` (Task 3), `Region`, `regionFor` (Task 2)
- Produces:
  - `config.ts`: `REGION = 'asia-northeast3'`, `KAKAO_REST_KEY`, `CLOVA_OCR_SECRET` (secret), `CLOVA_OCR_URL` (string param)
  - `interface PlaceResult extends KakaoPlace { region: string | null }`
  - `type KakaoSearch = (query: string, near: LatLng | null) => Promise<KakaoPlace[]>`
  - `CACHE_DAYS = 7`
  - `searchPlacesCore(db: Firestore, kakao: KakaoSearch, raw: unknown, now: Date): Promise<PlaceResult[]>`
  - callable `searchPlaces` — 입력 `{ query: string; lat?: number; lng?: number }`
  - `helpers.ts`: `PROJECT`, `testDb(): Firestore`, `clearFirestore(): Promise<void>`

- [ ] **Step 1: 테스트 헬퍼 작성**

`functions/test/emu/helpers.ts`:
```ts
import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore, Firestore } from 'firebase-admin/firestore';

export const PROJECT = 'demo-jjinhugi';

export function testDb(): Firestore {
  if (!getApps().length) initializeApp({ projectId: PROJECT });
  return getFirestore();
}

export async function clearFirestore(): Promise<void> {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: 'DELETE' });
}
```

- [ ] **Step 2: 실패하는 테스트 작성**

`functions/test/emu/search.test.ts`:
```ts
import { testDb, clearFirestore } from './helpers';
import { searchPlacesCore } from '../../src/search';
import { KakaoPlace } from '../../src/kakao';

const db = testDb();
const NOW = new Date('2026-10-07T03:00:00Z');
const places: KakaoPlace[] = [
  { placeId: '111', name: '성수 찐국밥', address: '서울 성동구 성수동2가 300-1', roadAddress: '서울 성동구 연무장길 10', lat: 37.54, lng: 127.05 },
  { placeId: '999', name: '강남 찐면', address: '서울 강남구 역삼동 1', roadAddress: '', lat: 37.5, lng: 127.03 },
];

beforeEach(async () => {
  await clearFirestore();
  await db.doc('config/regions').set({ list: [{ id: 'seongsu', name: '성수', gu: '성동구', dongs: ['성수'] }] });
});

test('카카오 결과를 지역 판정 후 반환하고 식당 문서 생성', async () => {
  const kakao = jest.fn().mockResolvedValue(places);
  const res = await searchPlacesCore(db, kakao, { query: '찐', lat: 37.5, lng: 127 }, NOW);
  expect(res.map((r) => [r.placeId, r.region])).toEqual([['111', 'seongsu'], ['999', null]]);
  expect(kakao).toHaveBeenCalledWith('찐', { lat: 37.5, lng: 127 });
  const doc = (await db.doc('restaurants/111').get()).data()!;
  expect(doc).toMatchObject({ name: '성수 찐국밥', region: 'seongsu', roadAddress: '서울 성동구 연무장길 10' });
  expect(typeof doc.geohash).toBe('string');
});

test('7일 내 같은 검색은 캐시 사용', async () => {
  const kakao = jest.fn().mockResolvedValue(places);
  await searchPlacesCore(db, kakao, { query: '찐', lat: 37.501, lng: 127.001 }, NOW);
  const res = await searchPlacesCore(db, kakao, { query: '찐', lat: 37.502, lng: 127.002 }, new Date(NOW.getTime() + 6 * 86_400_000));
  expect(kakao).toHaveBeenCalledTimes(1);
  expect(res.map((r) => r.placeId).sort()).toEqual(['111', '999']);
});

test('7일 지나면 다시 호출', async () => {
  const kakao = jest.fn().mockResolvedValue(places);
  await searchPlacesCore(db, kakao, { query: '찐' }, NOW);
  await searchPlacesCore(db, kakao, { query: '찐' }, new Date(NOW.getTime() + 8 * 86_400_000));
  expect(kakao).toHaveBeenCalledTimes(2);
});

test('재검색해도 집계 필드 보존', async () => {
  await db.doc('restaurants/111').set({ scoreSum: 25.5, reviewCount: 3, realScore: 8.5 });
  await searchPlacesCore(db, jest.fn().mockResolvedValue(places), { query: '찐' }, NOW);
  expect((await db.doc('restaurants/111').get()).data()).toMatchObject({ scoreSum: 25.5, reviewCount: 3, realScore: 8.5, name: '성수 찐국밥' });
});

test('빈 검색어 거절', async () => {
  await expect(searchPlacesCore(db, jest.fn(), { query: '  ' }, NOW)).rejects.toMatchObject({ code: 'invalid-argument' });
});

test('카카오 실패는 unavailable', async () => {
  await expect(searchPlacesCore(db, jest.fn().mockRejectedValue(new Error('kakao 429')), { query: '찐' }, NOW))
    .rejects.toMatchObject({ code: 'unavailable', message: 'kakao_unavailable' });
});
```

- [ ] **Step 3: 실패 확인**

Run: `cd functions && npm run test:emu`
Expected: FAIL — `Cannot find module '../../src/search'`

- [ ] **Step 4: 구현**

`functions/src/config.ts`:
```ts
import { defineSecret, defineString } from 'firebase-functions/params';

export const REGION = 'asia-northeast3';
export const KAKAO_REST_KEY = defineSecret('KAKAO_REST_KEY');
export const CLOVA_OCR_SECRET = defineSecret('CLOVA_OCR_SECRET');
export const CLOVA_OCR_URL = defineString('CLOVA_OCR_URL');
```

`functions/src/search.ts`:
```ts
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
```

`functions/src/index.ts`:
```ts
import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { searchPlaces } from './search';
```

- [ ] **Step 5: 통과 확인**

Run: `cd functions && npm run test:emu && npm run build`
Expected: PASS (rules 16 + search 6), `tsc` 에러 없음

- [ ] **Step 6: 커밋**

```bash
git add functions/src/config.ts functions/src/search.ts functions/src/index.ts functions/test/emu/helpers.ts functions/test/emu/search.test.ts
git commit -m "feat(functions): add searchPlaces with Kakao cache and restaurant upsert"
```

---

### Task 6: submitReview (영수증 검증 → 순위 반영 → 집계)

**Files:**
- Create: `functions/src/review.ts`
- Modify: `functions/src/index.ts` (export 추가)
- Test: `functions/test/unit/review-input.test.ts`, `functions/test/emu/review.test.ts`

**Interfaces:**
- Consumes: `Tier`, `TIERS`, `Ranking`, `emptyRanking`, `insertPlace`, `scoreChanges`, `scoresOf`, `deriveScores`, `round1`, `RestaurantSums` (Task 1) / `OcrReceipt`, `PlaceInfo`, `verifyReceipt`, `kstDate` (Task 2) / `clovaOcr` (Task 3) / `REGION`, `CLOVA_OCR_SECRET`, `CLOVA_OCR_URL` (Task 5)
- Produces:
  - `DAILY_REVIEW_LIMIT = 5`
  - `interface SubmitReviewInput { placeId: string; receiptPath: string; tier: Tier; rankIndex: number; eventJoined: boolean; eventStars: number | null; text: string; photos: string[] }`
  - `validateSubmitInput(uid: string, raw: unknown): SubmitReviewInput` — 실패 시 `HttpsError('invalid-argument', <필드명>)`
  - `interface SubmitDeps { ocr: (receiptPath: string) => Promise<OcrReceipt> }`
  - `submitReviewCore(db: Firestore, deps: SubmitDeps, uid: string, raw: unknown, now: Date): Promise<{ reviewId: string }>`
  - callable `submitReview`
  - 에러 코드: `not-found/place_not_found`, `failed-precondition/out_of_region`, `failed-precondition/no_user`, `resource-exhausted/daily_limit`, `unavailable/ocr_unavailable`, `failed-precondition/{unreadable|store_mismatch|date_expired}`, `already-exists/duplicate`

- [ ] **Step 1: 입력 검증 실패 테스트 작성**

`functions/test/unit/review-input.test.ts`:
```ts
import { validateSubmitInput } from '../../src/review';

const base = {
  placeId: 'p1', receiptPath: 'receipts/u1/r.jpg', tier: 'best', rankIndex: 0,
  eventJoined: false, eventStars: null, text: '국물이 진하고 고기가 많아요', photos: [],
};
const bad = (patch: object, field: string) => {
  let err: unknown;
  try {
    validateSubmitInput('u1', { ...base, ...patch });
  } catch (e) {
    err = e;
  }
  expect(err).toMatchObject({ code: 'invalid-argument', message: field });
};

test('정상 입력은 trim된 값 반환', () => {
  expect(validateSubmitInput('u1', { ...base, text: '  국물이 진하고 고기가 많아요  ' }).text).toBe('국물이 진하고 고기가 많아요');
});
test('남의 영수증 경로', () => bad({ receiptPath: 'receipts/u2/r.jpg' }, 'receiptPath'));
test('잘못된 등급', () => bad({ tier: 'great' }, 'tier'));
test('음수 순위', () => bad({ rankIndex: -1 }, 'rankIndex'));
test('이벤트 참여인데 별점 없음', () => bad({ eventJoined: true, eventStars: null }, 'eventStars'));
test('이벤트 별점 범위 밖', () => bad({ eventJoined: true, eventStars: 6 }, 'eventStars'));
test('이벤트 미참여인데 별점 있음', () => bad({ eventStars: 5 }, 'eventStars'));
test('한줄평 10자 미만', () => bad({ text: '맛있어요' }, 'text'));
test('한줄평 300자 초과', () => bad({ text: '가'.repeat(301) }, 'text'));
test('사진 6장', () => bad({ photos: Array(6).fill('photos/u1/a.jpg') }, 'photos'));
test('남의 사진 경로', () => bad({ photos: ['photos/u2/a.jpg'] }, 'photos'));
```

- [ ] **Step 2: Emulator 통합 테스트 작성**

`functions/test/emu/review.test.ts`:
```ts
import { testDb, clearFirestore } from './helpers';
import { submitReviewCore } from '../../src/review';
import { OcrReceipt } from '../../src/receipt';

const db = testDb();
const NOW = new Date('2026-10-07T03:00:00Z'); // KST 2026-10-07

const PLACES: Record<string, { name: string; address: string; roadAddress: string; region: string | null }> = {
  p1: { name: '성수 찐국밥', address: '서울 성동구 성수동2가 300-1', roadAddress: '서울 성동구 연무장길 10', region: 'seongsu' },
  p2: { name: '성수 찐카페', address: '서울 성동구 성수동1가 10', roadAddress: '서울 성동구 성수이로 20', region: 'seongsu' },
  p3: { name: '성수 찐면옥', address: '서울 성동구 성수동1가 20', roadAddress: '서울 성동구 성수이로 30', region: 'seongsu' },
  far: { name: '강남 찐면', address: '서울 강남구 역삼동 1', roadAddress: '', region: null },
};

// 영수증 경로 규칙: receipts/{uid}/{placeId}-{승인번호}.jpg → 해당 식당 정상 영수증
const ocr = async (path: string): Promise<OcrReceipt> => {
  const [placeId, approvalNo] = path.split('/')[2].replace('.jpg', '').split('-');
  const p = PLACES[placeId];
  return { storeName: p.name, address: p.roadAddress || p.address, date: '2026-10-06', total: 10000, approvalNo };
};
const deps = { ocr };

const input = (uid: string, placeId: string, approvalNo: string, extra: object = {}) => ({
  placeId, receiptPath: `receipts/${uid}/${placeId}-${approvalNo}.jpg`, tier: 'best', rankIndex: 0,
  eventJoined: false, eventStars: null, text: '국물이 진하고 고기가 많아요', photos: [], ...extra,
});
const user = (uid: string) => db.doc(`users/${uid}`).get().then((s) => s.data()!);
const rest = (id: string) => db.doc(`restaurants/${id}`).get().then((s) => s.data()!);
const review = (id: string) => db.doc(`reviews/${id}`).get().then((s) => s.data());

beforeEach(async () => {
  await clearFirestore();
  for (const [id, p] of Object.entries(PLACES)) await db.doc(`restaurants/${id}`).set(p);
  for (const uid of ['u1', 'u2', 'u3']) {
    await db.doc(`users/${uid}`).set({ verifiedReviewCount: 0, ranking: { best: [], ok: [], bad: [] }, dailyReviewCount: 0, dailyReviewDate: '' });
  }
});

test('첫 후기 작성', async () => {
  const res = await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1001'), NOW);
  expect(res).toEqual({ reviewId: 'u1_p1' });
  expect(await review('u1_p1')).toMatchObject({ uid: 'u1', restaurantId: 'p1', region: 'seongsu', tier: 'best', personalScore: 8.5, visitDate: '2026-10-06', likeCount: 0 });
  expect(await user('u1')).toMatchObject({ verifiedReviewCount: 1, ranking: { best: ['p1'], ok: [], bad: [] }, dailyReviewCount: 1, dailyReviewDate: '2026-10-07' });
  expect(await rest('p1')).toMatchObject({ scoreSum: 8.5, reviewCount: 1, eventStarSum: 0, eventReviewCount: 0, realScore: null });
});

test('새 식당을 1위로 넣으면 기존 후기·식당 점수 재계산', async () => {
  await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1001'), NOW);
  await submitReviewCore(db, deps, 'u1', input('u1', 'p2', '1002', { rankIndex: 0 }), NOW);
  expect((await review('u1_p1'))!.personalScore).toBe(7.8);
  expect((await review('u1_p2'))!.personalScore).toBe(9.3);
  expect((await rest('p1')).scoreSum).toBe(7.8);
  expect((await rest('p2')).scoreSum).toBe(9.3);
});

test('등급 이동: 최고→별로 시 남은 최고 식당 점수도 재계산', async () => {
  await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1001'), NOW);
  await submitReviewCore(db, deps, 'u1', input('u1', 'p2', '1002', { rankIndex: 1 }), NOW); // best: [p1, p2]
  await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1003', { tier: 'bad' }), NOW); // 재방문, best: [p2], bad: [p1]
  expect((await user('u1')).ranking).toEqual({ best: ['p2'], ok: [], bad: ['p1'] });
  expect((await review('u1_p2'))!.personalScore).toBe(8.5);
  expect((await rest('p2')).scoreSum).toBe(8.5);
  expect((await rest('p1')).scoreSum).toBe(2);
});

test('재방문: 카운트 중복 없음, 이벤트 점수 교체', async () => {
  await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1001', { eventJoined: true, eventStars: 5 }), NOW);
  await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1002', { eventJoined: true, eventStars: 3 }), NOW);
  expect(await rest('p1')).toMatchObject({ reviewCount: 1, eventReviewCount: 1, eventStarSum: 3 });
  expect((await user('u1')).verifiedReviewCount).toBe(1);
  await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1003'), NOW);
  expect(await rest('p1')).toMatchObject({ reviewCount: 1, eventReviewCount: 0, eventStarSum: 0 });
});

test('3명이 쓰면 찐점수·거품지수 계산', async () => {
  for (const [i, uid] of ['u1', 'u2', 'u3'].entries()) {
    await submitReviewCore(db, deps, uid, input(uid, 'p1', `200${i}`, { tier: 'ok', eventJoined: true, eventStars: 5 }), NOW);
  }
  expect(await rest('p1')).toMatchObject({ reviewCount: 3, realScore: 5.5, eventScore: 10, bubble: 4.5 });
});

test('같은 영수증 재사용은 duplicate, 아무것도 안 바뀜', async () => {
  await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1001'), NOW);
  await expect(submitReviewCore(db, deps, 'u2', { ...input('u2', 'p1', '1001') }, NOW))
    .rejects.toMatchObject({ code: 'already-exists', message: 'duplicate' });
  expect(await review('u2_p1')).toBeUndefined();
  expect((await rest('p1')).reviewCount).toBe(1);
});

test('하루 5개 제한', async () => {
  await db.doc('users/u1').update({ dailyReviewDate: '2026-10-07', dailyReviewCount: 5 });
  await expect(submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1001'), NOW))
    .rejects.toMatchObject({ code: 'resource-exhausted', message: 'daily_limit' });
});

test('어제 카운트는 오늘 초기화', async () => {
  await db.doc('users/u1').update({ dailyReviewDate: '2026-10-06', dailyReviewCount: 5 });
  await submitReviewCore(db, deps, 'u1', input('u1', 'p1', '1001'), NOW);
  expect((await user('u1')).dailyReviewCount).toBe(1);
});

test('베타 지역 밖 식당 거절', async () => {
  await expect(submitReviewCore(db, deps, 'u1', input('u1', 'far', '1001'), NOW))
    .rejects.toMatchObject({ code: 'failed-precondition', message: 'out_of_region' });
});

test('검색 안 된 식당은 not-found', async () => {
  await expect(submitReviewCore(db, deps, 'u1', { ...input('u1', 'p1', '1001'), placeId: 'nope' }, NOW))
    .rejects.toMatchObject({ code: 'not-found', message: 'place_not_found' });
});

test('다른 가게 영수증은 store_mismatch, 기록 없음', async () => {
  await expect(submitReviewCore(db, deps, 'u1', { ...input('u1', 'p2', '1001'), placeId: 'p1' }, NOW))
    .rejects.toMatchObject({ code: 'failed-precondition', message: 'store_mismatch' });
  expect(await review('u1_p1')).toBeUndefined();
});

test('OCR 장애는 unavailable', async () => {
  const broken = { ocr: async () => { throw new Error('clova 500'); } };
  await expect(submitReviewCore(db, broken, 'u1', input('u1', 'p1', '1001'), NOW))
    .rejects.toMatchObject({ code: 'unavailable', message: 'ocr_unavailable' });
});
```

- [ ] **Step 3: 실패 확인**

Run: `cd functions && npm run test:unit`
Expected: FAIL — `Cannot find module '../../src/review'`

- [ ] **Step 4: 구현**

`functions/src/review.ts`:
```ts
import { Firestore, FieldValue, getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { Tier, TIERS, Ranking, emptyRanking, insertPlace, scoreChanges, scoresOf, deriveScores, round1, RestaurantSums } from './scoring';
import { OcrReceipt, PlaceInfo, verifyReceipt, kstDate } from './receipt';
import { clovaOcr } from './ocr';
import { REGION, CLOVA_OCR_SECRET, CLOVA_OCR_URL } from './config';

export const DAILY_REVIEW_LIMIT = 5;

export interface SubmitReviewInput {
  placeId: string; receiptPath: string; tier: Tier; rankIndex: number;
  eventJoined: boolean; eventStars: number | null; text: string; photos: string[];
}
export interface SubmitDeps { ocr: (receiptPath: string) => Promise<OcrReceipt> }

const invalid = (field: string): never => { throw new HttpsError('invalid-argument', field); };

/* eslint-disable @typescript-eslint/no-explicit-any */
export function validateSubmitInput(uid: string, raw: unknown): SubmitReviewInput {
  const d = (raw ?? {}) as any;
  if (typeof d.placeId !== 'string' || !d.placeId || d.placeId.includes('/')) invalid('placeId');
  if (typeof d.receiptPath !== 'string' || !d.receiptPath.startsWith(`receipts/${uid}/`)) invalid('receiptPath');
  if (!TIERS.includes(d.tier)) invalid('tier');
  if (!Number.isInteger(d.rankIndex) || d.rankIndex < 0) invalid('rankIndex');
  if (typeof d.eventJoined !== 'boolean') invalid('eventJoined');
  const starsOk = d.eventJoined ? Number.isInteger(d.eventStars) && d.eventStars >= 1 && d.eventStars <= 5 : d.eventStars == null;
  if (!starsOk) invalid('eventStars');
  const text = typeof d.text === 'string' ? d.text.trim() : '';
  if (text.length < 10 || text.length > 300) invalid('text');
  const photos = d.photos ?? [];
  if (!Array.isArray(photos) || photos.length > 5 || photos.some((p: unknown) => typeof p !== 'string' || !p.startsWith(`photos/${uid}/`))) invalid('photos');
  return {
    placeId: d.placeId, receiptPath: d.receiptPath, tier: d.tier, rankIndex: d.rankIndex,
    eventJoined: d.eventJoined, eventStars: d.eventJoined ? d.eventStars : null, text, photos,
  };
}

export async function submitReviewCore(db: Firestore, deps: SubmitDeps, uid: string, raw: unknown, now: Date): Promise<{ reviewId: string }> {
  const input = validateSubmitInput(uid, raw);
  const today = kstDate(now);

  const place = (await db.doc(`restaurants/${input.placeId}`).get()).data();
  if (!place) throw new HttpsError('not-found', 'place_not_found');
  if (!place.region) throw new HttpsError('failed-precondition', 'out_of_region');

  const userRef = db.doc(`users/${uid}`);
  const user0 = (await userRef.get()).data();
  if (!user0) throw new HttpsError('failed-precondition', 'no_user');
  // OCR 비용 아끼려고 트랜잭션 전에 한 번 더 확인
  if (user0.dailyReviewDate === today && user0.dailyReviewCount >= DAILY_REVIEW_LIMIT) throw new HttpsError('resource-exhausted', 'daily_limit');

  let ocr: OcrReceipt;
  try {
    ocr = await deps.ocr(input.receiptPath);
  } catch {
    throw new HttpsError('unavailable', 'ocr_unavailable');
  }
  const receipt = verifyReceipt(ocr, place as PlaceInfo, now);
  if (!receipt.ok) throw new HttpsError('failed-precondition', receipt.reason);

  const reviewId = `${uid}_${input.placeId}`;
  const reviewRef = db.doc(`reviews/${reviewId}`);
  const keyRef = db.doc(`receiptKeys/${receipt.hash}`);

  await db.runTransaction(async (tx) => {
    const [userSnap, keySnap, oldSnap] = await tx.getAll(userRef, keyRef, reviewRef);
    if (keySnap.exists) throw new HttpsError('already-exists', 'duplicate');
    const user = userSnap.data()!;
    const dailyCount = user.dailyReviewDate === today ? user.dailyReviewCount : 0;
    if (dailyCount >= DAILY_REVIEW_LIMIT) throw new HttpsError('resource-exhausted', 'daily_limit');

    const before: Ranking = user.ranking ?? emptyRanking();
    const after = insertPlace(before, input.placeId, input.tier, input.rankIndex);
    const changes = scoreChanges(before, after);
    const ids = [...new Set([input.placeId, ...changes.keys()])];
    const restSnaps = await tx.getAll(...ids.map((id) => db.doc(`restaurants/${id}`)));
    const old = oldSnap.data();
    const isNew = !old;

    // --- 이하 쓰기만 ---
    ids.forEach((id, i) => {
      const s = restSnaps[i].data() ?? {};
      const sums: RestaurantSums = {
        scoreSum: s.scoreSum ?? 0, reviewCount: s.reviewCount ?? 0,
        eventStarSum: s.eventStarSum ?? 0, eventReviewCount: s.eventReviewCount ?? 0,
      };
      const c = changes.get(id);
      if (c) sums.scoreSum = round1(sums.scoreSum - (c.old ?? 0) + c.new);
      if (id === input.placeId) {
        if (isNew) sums.reviewCount += 1;
        if (old?.eventJoined) { sums.eventStarSum -= old.eventStars; sums.eventReviewCount -= 1; }
        if (input.eventJoined) { sums.eventStarSum += input.eventStars!; sums.eventReviewCount += 1; }
      } else if (c) {
        tx.update(db.doc(`reviews/${uid}_${id}`), { personalScore: c.new });
      }
      tx.set(db.doc(`restaurants/${id}`), { ...sums, ...deriveScores(sums) }, { merge: true });
    });

    tx.set(reviewRef, {
      uid, restaurantId: input.placeId, region: place.region, tier: input.tier,
      personalScore: scoresOf(after).get(input.placeId)!,
      eventJoined: input.eventJoined, eventStars: input.eventStars, text: input.text, photos: input.photos,
      visitDate: receipt.visitDate, likeCount: old?.likeCount ?? 0,
      createdAt: old?.createdAt ?? FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(keyRef, { uid, reviewId, createdAt: FieldValue.serverTimestamp() });
    tx.update(userRef, {
      ranking: after,
      verifiedReviewCount: (user.verifiedReviewCount ?? 0) + (isNew ? 1 : 0),
      dailyReviewDate: today,
      dailyReviewCount: dailyCount + 1,
    });
  });
  return { reviewId };
}

export const submitReview = onCall({ region: REGION, secrets: [CLOVA_OCR_SECRET], timeoutSeconds: 60 }, (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'login_required');
  const ocr = async (path: string) => {
    const [buf] = await getStorage().bucket().file(path).download();
    return clovaOcr(buf, { url: CLOVA_OCR_URL.value(), secret: CLOVA_OCR_SECRET.value() });
  };
  return submitReviewCore(getFirestore(), { ocr }, req.auth.uid, req.data, new Date());
});
```

`functions/src/index.ts`에 추가:
```ts
export { submitReview } from './review';
```

- [ ] **Step 5: 통과 확인**

Run: `cd functions && npm run test:unit && npm run test:emu && npm run build`
Expected: PASS (review-input 11, review 12 추가), `tsc` 에러 없음

- [ ] **Step 6: 커밋**

```bash
git add functions/src/review.ts functions/src/index.ts functions/test/unit/review-input.test.ts functions/test/emu/review.test.ts
git commit -m "feat(functions): add submitReview with receipt check, ranking and aggregation"
```

---

### Task 7: 로그인 (kakaoLogin, ensureUser) + 칭호

**Files:**
- Create: `functions/src/title.ts`, `functions/src/auth.ts`
- Modify: `functions/src/index.ts`
- Test: `functions/test/unit/title.test.ts`, `functions/test/emu/auth.test.ts`

**Interfaces:**
- Consumes: `kakaoMe`, `KakaoProfile` (Task 3), `emptyRanking` (Task 1), `REGION` (Task 5)
- Produces:
  - `titleFor(likes: number): string` — `'찐린이' | '찐후기러' | '찐고수'`
  - `newUserDoc(displayName: string | undefined, rand?: () => number): Record<string, unknown>`
  - `kakaoLoginCore(auth: Auth, me: (token: string) => Promise<KakaoProfile>, raw: unknown): Promise<{ token: string }>` — uid = `kakao:{카카오id}`
  - `ensureUserCore(db: Firestore, uid: string, displayName: string | undefined): Promise<void>` — 없을 때만 생성
  - callable `kakaoLogin` (비로그인 호출) 입력 `{ accessToken }` → `{ token }`
  - callable `ensureUser` (로그인 필요) → `{ ok: true }`

- [ ] **Step 1: 실패하는 테스트 작성**

`functions/test/unit/title.test.ts`:
```ts
import { titleFor } from '../../src/title';

test.each([[0, '찐린이'], [9, '찐린이'], [10, '찐후기러'], [49, '찐후기러'], [50, '찐고수'], [999, '찐고수']])('%i따봉 → %s', (n, t) => {
  expect(titleFor(n)).toBe(t);
});
```

`functions/test/emu/auth.test.ts`:
```ts
import { getAuth } from 'firebase-admin/auth';
import { testDb, clearFirestore } from './helpers';
import { kakaoLoginCore, ensureUserCore, newUserDoc } from '../../src/auth';

const db = testDb();
const auth = getAuth();

beforeEach(async () => {
  await clearFirestore();
  await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/projects/demo-jjinhugi/accounts`, { method: 'DELETE' });
});

test('카카오 로그인: 유저 생성 후 커스텀 토큰', async () => {
  const me = jest.fn().mockResolvedValue({ id: '42', nickname: '찐이' });
  const { token } = await kakaoLoginCore(auth, me, { accessToken: 'tok' });
  expect(typeof token).toBe('string');
  expect((await auth.getUser('kakao:42')).displayName).toBe('찐이');
  await kakaoLoginCore(auth, me, { accessToken: 'tok' }); // 두 번째는 기존 유저 재사용
  expect((await auth.listUsers()).users).toHaveLength(1);
});

test('카카오 토큰 무효는 unauthenticated', async () => {
  const me = jest.fn().mockRejectedValue(new Error('kakao_me 401'));
  await expect(kakaoLoginCore(auth, me, { accessToken: 'bad' })).rejects.toMatchObject({ code: 'unauthenticated', message: 'kakao_invalid_token' });
});

test('accessToken 누락은 invalid-argument', async () => {
  await expect(kakaoLoginCore(auth, jest.fn(), {})).rejects.toMatchObject({ code: 'invalid-argument' });
});

test('ensureUser: 없으면 생성, 있으면 유지', async () => {
  await ensureUserCore(db, 'u1', '찐이');
  expect((await db.doc('users/u1').get()).data()).toMatchObject({ nickname: '찐이', title: '찐린이', likesReceived: 0, verifiedReviewCount: 0 });
  await db.doc('users/u1').update({ likesReceived: 7 });
  await ensureUserCore(db, 'u1', '다른이름');
  expect((await db.doc('users/u1').get()).data()).toMatchObject({ nickname: '찐이', likesReceived: 7 });
});

test('닉네임 없으면 찐린이+4자리', () => {
  expect(newUserDoc(undefined, () => 0).nickname).toBe('찐린이1000');
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd functions && npm run test:unit`
Expected: FAIL — `Cannot find module '../../src/title'`

- [ ] **Step 3: 구현**

`functions/src/title.ts`:
```ts
export function titleFor(likes: number): string {
  if (likes >= 50) return '찐고수';
  if (likes >= 10) return '찐후기러';
  return '찐린이';
}
```

`functions/src/auth.ts`:
```ts
import { Auth, getAuth } from 'firebase-admin/auth';
import { Firestore, FieldValue, getFirestore } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { KakaoProfile, kakaoMe } from './kakao';
import { emptyRanking } from './scoring';
import { titleFor } from './title';
import { REGION } from './config';

export function newUserDoc(displayName: string | undefined, rand: () => number = Math.random): Record<string, unknown> {
  return {
    nickname: displayName?.trim().slice(0, 20) || `찐린이${Math.floor(rand() * 9000 + 1000)}`,
    title: titleFor(0),
    likesReceived: 0,
    verifiedReviewCount: 0,
    ranking: emptyRanking(),
    dailyReviewCount: 0,
    dailyReviewDate: '',
    createdAt: FieldValue.serverTimestamp(),
  };
}

export async function kakaoLoginCore(auth: Auth, me: (token: string) => Promise<KakaoProfile>, raw: unknown): Promise<{ token: string }> {
  const accessToken = (raw as { accessToken?: unknown } | null)?.accessToken;
  if (typeof accessToken !== 'string' || !accessToken) throw new HttpsError('invalid-argument', 'accessToken');
  let profile: KakaoProfile;
  try {
    profile = await me(accessToken);
  } catch {
    throw new HttpsError('unauthenticated', 'kakao_invalid_token');
  }
  const uid = `kakao:${profile.id}`;
  try {
    await auth.getUser(uid);
  } catch (e) {
    if ((e as { code?: string }).code !== 'auth/user-not-found') throw e;
    await auth.createUser({ uid, displayName: profile.nickname ?? undefined });
  }
  return { token: await auth.createCustomToken(uid) };
}

export async function ensureUserCore(db: Firestore, uid: string, displayName: string | undefined): Promise<void> {
  const ref = db.doc(`users/${uid}`);
  await db.runTransaction(async (tx) => {
    if (!(await tx.get(ref)).exists) tx.set(ref, newUserDoc(displayName));
  });
}

export const kakaoLogin = onCall({ region: REGION }, (req) => kakaoLoginCore(getAuth(), (t) => kakaoMe(t), req.data));

export const ensureUser = onCall({ region: REGION }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'login_required');
  await ensureUserCore(getFirestore(), req.auth.uid, req.auth.token.name as string | undefined);
  return { ok: true };
});
```

`functions/src/index.ts`에 추가:
```ts
export { kakaoLogin, ensureUser } from './auth';
```

- [ ] **Step 4: 통과 확인**

Run: `cd functions && npm run test:unit && npm run test:emu && npm run build`
Expected: PASS (title 6, auth 5 추가)

- [ ] **Step 5: 커밋**

```bash
git add functions/src/title.ts functions/src/auth.ts functions/src/index.ts functions/test/unit/title.test.ts functions/test/emu/auth.test.ts
git commit -m "feat(functions): add Kakao login, ensureUser and titles"
```

---

### Task 8: onLikeWrite (따봉 집계 + 칭호 갱신)

**Files:**
- Create: `functions/src/likes.ts`
- Modify: `functions/src/index.ts`
- Test: `functions/test/emu/likes.test.ts`

**Interfaces:**
- Consumes: `titleFor` (Task 7), `kstDate` (Task 2), `REGION` (Task 5)
- Produces:
  - `applyLike(db: Firestore, reviewId: string, delta: 1 | -1, now: Date): Promise<void>` — `reviews.likeCount`, 작성자 `users.likesReceived`·`title`, `likeMonths/{yyyy-MM}_{region}_{authorUid}.likes` 갱신
  - Firestore 트리거 `onLikeWrite` (`reviews/{reviewId}/likes/{likerUid}`)

- [ ] **Step 1: 실패하는 테스트 작성**

`functions/test/emu/likes.test.ts`:
```ts
import { testDb, clearFirestore } from './helpers';
import { applyLike } from '../../src/likes';

const db = testDb();
const NOW = new Date('2026-10-07T03:00:00Z');

beforeEach(async () => {
  await clearFirestore();
  await db.doc('reviews/carol_p1').set({ uid: 'carol', region: 'seongsu', likeCount: 0 });
  await db.doc('users/carol').set({ likesReceived: 9, title: '찐린이' });
});

test('따봉 +1: 후기·유저·월간 집계, 10개 되면 칭호 승급', async () => {
  await applyLike(db, 'carol_p1', 1, NOW);
  expect((await db.doc('reviews/carol_p1').get()).data()!.likeCount).toBe(1);
  expect((await db.doc('users/carol').get()).data()).toMatchObject({ likesReceived: 10, title: '찐후기러' });
  expect((await db.doc('likeMonths/2026-10_seongsu_carol').get()).data()).toEqual({ uid: 'carol', region: 'seongsu', month: '2026-10', likes: 1 });
});

test('따봉 취소 -1: 칭호 강등, 0 아래로 안 내려감', async () => {
  await applyLike(db, 'carol_p1', 1, NOW);
  await applyLike(db, 'carol_p1', -1, NOW);
  expect((await db.doc('users/carol').get()).data()).toMatchObject({ likesReceived: 9, title: '찐린이' });
  await db.doc('users/carol').update({ likesReceived: 0 });
  await applyLike(db, 'carol_p1', -1, NOW);
  expect((await db.doc('users/carol').get()).data()!.likesReceived).toBe(0);
});

test('삭제된 후기는 무시', async () => {
  await expect(applyLike(db, 'nope', 1, NOW)).resolves.toBeUndefined();
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd functions && npm run test:emu`
Expected: FAIL — `Cannot find module '../../src/likes'`

- [ ] **Step 3: 구현**

`functions/src/likes.ts`:
```ts
import { Firestore, FieldValue, getFirestore } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { titleFor } from './title';
import { kstDate } from './receipt';
import { REGION } from './config';

export async function applyLike(db: Firestore, reviewId: string, delta: 1 | -1, now: Date): Promise<void> {
  const reviewRef = db.doc(`reviews/${reviewId}`);
  const review = (await reviewRef.get()).data();
  if (!review) return;
  const month = kstDate(now).slice(0, 7);
  const userRef = db.doc(`users/${review.uid}`);
  await db.runTransaction(async (tx) => {
    const user = (await tx.get(userRef)).data();
    const likes = Math.max(0, (user?.likesReceived ?? 0) + delta);
    tx.update(reviewRef, { likeCount: FieldValue.increment(delta) });
    tx.set(userRef, { likesReceived: likes, title: titleFor(likes) }, { merge: true });
    // ponytail: 이전 달 따봉을 이번 달에 취소하면 이번 달 집계가 -1. 대마왕은 운영자 확인 단계에서 걸러짐.
    tx.set(
      db.doc(`likeMonths/${month}_${review.region}_${review.uid}`),
      { uid: review.uid, region: review.region, month, likes: FieldValue.increment(delta) },
      { merge: true },
    );
  });
}

// ponytail: 트리거는 at-least-once라 드물게 중복 집계 가능. 베타 규모에선 허용, 문제 되면 event.id로 멱등 처리.
export const onLikeWrite = onDocumentWritten({ document: 'reviews/{reviewId}/likes/{likerUid}', region: REGION }, async (event) => {
  const before = event.data?.before.exists ?? false;
  const after = event.data?.after.exists ?? false;
  if (before === after) return;
  await applyLike(getFirestore(), event.params.reviewId, after ? 1 : -1, new Date());
});
```

`functions/src/index.ts`에 추가:
```ts
export { onLikeWrite } from './likes';
```

- [ ] **Step 4: 통과 확인**

Run: `cd functions && npm run test:emu && npm run build`
Expected: PASS (likes 3 추가)

- [ ] **Step 5: 커밋**

```bash
git add functions/src/likes.ts functions/src/index.ts functions/test/emu/likes.test.ts
git commit -m "feat(functions): add like aggregation trigger with title updates"
```

---

### Task 9: monthlyCrown (월간 대마왕 후보 선정)

**Files:**
- Create: `functions/src/crown.ts`
- Modify: `functions/src/index.ts`
- Test: `functions/test/unit/crown-months.test.ts`, `functions/test/emu/crown.test.ts`

**Interfaces:**
- Consumes: `Region` (Task 2), `kstDate` (Task 2), `REGION` (Task 5)
- Produces:
  - `crownMonths(now: Date): { scoreMonth: string; displayMonth: string }` — KST 기준 지난달·이번달
  - `pickCrowns(db: Firestore, now: Date): Promise<void>` — 지역마다 `crowns/{displayMonth}_{regionId}` = `{ uid, likes, region, scoreMonth, displayMonth, status: 'pending' }`
  - 스케줄 함수 `monthlyCrown` (매월 1일 00:00 KST)
  - 운영자는 콘솔에서 `status`를 `'confirmed'`로 바꿔 확정. 앱은 `displayMonth == 이번달 && status == 'confirmed'`만 표시

- [ ] **Step 1: 실패하는 테스트 작성**

`functions/test/unit/crown-months.test.ts`:
```ts
import { crownMonths } from '../../src/crown';

test('10월 1일 KST 0시 → 9월 집계, 10월 표시', () => {
  expect(crownMonths(new Date('2026-09-30T15:00:00Z'))).toEqual({ scoreMonth: '2026-09', displayMonth: '2026-10' });
});
test('1월 → 전년 12월', () => {
  expect(crownMonths(new Date('2027-01-01T00:00:00Z'))).toEqual({ scoreMonth: '2026-12', displayMonth: '2027-01' });
});
```

`functions/test/emu/crown.test.ts`:
```ts
import { testDb, clearFirestore } from './helpers';
import { pickCrowns } from '../../src/crown';

const db = testDb();
const NOW = new Date('2026-09-30T15:00:00Z'); // KST 10/1 00:00

beforeEach(async () => {
  await clearFirestore();
  await db.doc('config/regions').set({ list: [
    { id: 'seongsu', name: '성수', gu: '성동구', dongs: ['성수'] },
    { id: 'gangnam', name: '강남', gu: '강남구', dongs: ['역삼'] },
  ] });
  const lm = (month: string, region: string, uid: string, likes: number) =>
    db.doc(`likeMonths/${month}_${region}_${uid}`).set({ month, region, uid, likes });
  await lm('2026-09', 'seongsu', 'a', 5);
  await lm('2026-09', 'seongsu', 'b', 12);
  await lm('2026-08', 'seongsu', 'c', 99); // 다른 달
  await lm('2026-09', 'gangnam', 'd', 0); // 0따봉은 제외
});

test('지역별 지난달 1위를 pending으로 기록', async () => {
  await pickCrowns(db, NOW);
  expect((await db.doc('crowns/2026-10_seongsu').get()).data()).toEqual({
    uid: 'b', likes: 12, region: 'seongsu', scoreMonth: '2026-09', displayMonth: '2026-10', status: 'pending',
  });
  expect((await db.doc('crowns/2026-10_gangnam').get()).exists).toBe(false);
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd functions && npm run test:unit`
Expected: FAIL — `Cannot find module '../../src/crown'`

- [ ] **Step 3: 구현**

`functions/src/crown.ts`:
```ts
import { Firestore, getFirestore } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { Region } from './address';
import { kstDate } from './receipt';
import { REGION } from './config';

export function crownMonths(now: Date): { scoreMonth: string; displayMonth: string } {
  const displayMonth = kstDate(now).slice(0, 7);
  const [y, m] = displayMonth.split('-').map(Number);
  const scoreMonth = m === 1 ? `${y - 1}-12` : `${y}-${String(m - 1).padStart(2, '0')}`;
  return { scoreMonth, displayMonth };
}

export async function pickCrowns(db: Firestore, now: Date): Promise<void> {
  const { scoreMonth, displayMonth } = crownMonths(now);
  const regions: Region[] = (await db.doc('config/regions').get()).data()?.list ?? [];
  for (const r of regions) {
    const top = await db.collection('likeMonths')
      .where('month', '==', scoreMonth).where('region', '==', r.id)
      .orderBy('likes', 'desc').limit(1).get();
    const best = top.docs[0]?.data();
    if (!best || best.likes <= 0) continue;
    await db.doc(`crowns/${displayMonth}_${r.id}`).set({
      uid: best.uid, likes: best.likes, region: r.id, scoreMonth, displayMonth, status: 'pending',
    });
  }
}

export const monthlyCrown = onSchedule({ schedule: '0 0 1 * *', timeZone: 'Asia/Seoul', region: REGION }, async () => {
  await pickCrowns(getFirestore(), new Date());
});
```

`functions/src/index.ts`에 추가:
```ts
export { monthlyCrown } from './crown';
```

- [ ] **Step 4: 통과 확인**

Run: `cd functions && npm run test:unit && npm run test:emu && npm run build`
Expected: 전부 PASS, `tsc` 에러 없음

- [ ] **Step 5: 커밋**

```bash
git add functions/src/crown.ts functions/src/index.ts functions/test/unit/crown-months.test.ts functions/test/emu/crown.test.ts
git commit -m "feat(functions): add monthly crown selection"
```

---

### Task 10: 배포 준비 (사람 + 실행자)

**Files:**
- Create: `storage-lifecycle.json`
- Create: `docs/deploy.md`

**Interfaces:**
- Consumes: Task 1~9 전체

- [ ] **Step 1: 영수증 30일 삭제 규칙 작성**

`storage-lifecycle.json`:
```json
{ "rule": [{ "action": { "type": "Delete" }, "condition": { "age": 30, "matchesPrefix": ["receipts/"] } }] }
```

- [ ] **Step 2: 배포 절차 문서 작성**

`docs/deploy.md`:
````markdown
# 배포 절차

## 1회 준비 (사람)
1. Firebase 콘솔에서 프로젝트 생성 (Blaze 요금제 — Functions·Secret 필수), 위치 `asia-northeast3`
2. Authentication → Apple 공급자 활성화
3. 카카오 디벨로퍼스 앱 생성 → REST API 키, 네이티브 앱 키 확보, 카카오 로그인 활성화
4. NAVER Cloud CLOVA OCR → Receipt 도메인 생성 → Invoke URL, Secret Key 확보
5. `.firebaserc`에 실 프로젝트 별칭 추가: `firebase use --add` → 별칭 `prod`

## 시크릿·파라미터
```bash
firebase use prod
firebase functions:secrets:set KAKAO_REST_KEY
firebase functions:secrets:set CLOVA_OCR_SECRET
echo "CLOVA_OCR_URL=<Invoke URL>" > functions/.env.prod
```

## 배포
```bash
cd functions && npm run test:unit && npm run test:emu && cd ..
firebase deploy --only firestore,storage,functions
gcloud storage buckets update gs://<프로젝트ID>.firebasestorage.app --lifecycle-file=storage-lifecycle.json
```

## 베타 지역 등록 (콘솔 → Firestore)
`config/regions` 문서: `{ list: [{ id: "seongsu", name: "성수", gu: "성동구", dongs: ["성수"] }] }`

## 매월 1일
콘솔 → `crowns` 컬렉션 → 이번 달 `pending` 문서 확인 → 담합 의심 없으면 `status`를 `confirmed`로 변경
````

- [ ] **Step 3: 전체 검증**

Run: `cd functions && npm run test:unit && npm run test:emu && npm run build`
Expected: 전부 PASS, `lib/index.js` 생성

- [ ] **Step 4: 커밋**

```bash
git add storage-lifecycle.json docs/deploy.md
git commit -m "docs: add deploy guide and receipt lifecycle rule"
```

---

## 앱 계약 (플랜 2 Flutter 앱이 사용)

모든 callable은 리전 `asia-northeast3`. 에러는 `FirebaseFunctionsException.code` / `.message`로 구분.

| callable | 인증 | 입력 | 출력 | 에러 message |
|---|---|---|---|---|
| `kakaoLogin` | 불필요 | `{accessToken}` (카카오 SDK 토큰) | `{token}` → `signInWithCustomToken` | `kakao_invalid_token` |
| `ensureUser` | 필요 | 없음 | `{ok:true}` — **로그인 직후 매번 호출** | |
| `searchPlaces` | 필요 | `{query, lat?, lng?}` | `PlaceResult[]` (`placeId,name,address,roadAddress,lat,lng,region`) | `kakao_unavailable` |
| `submitReview` | 필요 | `SubmitReviewInput` | `{reviewId}` | `place_not_found`, `out_of_region`, `daily_limit`, `ocr_unavailable`, `unreadable`, `store_mismatch`, `date_expired`, `duplicate`, 필드명(invalid-argument) |

후기 작성 순서 (앱):
1. `searchPlaces` → `region == null`이면 "베타 지역 아님" 안내, 진행 불가
2. 영수증 JPEG 업로드 → `receipts/{uid}/{uuid}.jpg` (10MB 미만, `image/jpeg`)
3. 사진 업로드 → `photos/{uid}/{uuid}.jpg`
4. 등급 선택 후 이진 비교: `users/{uid}.ranking[tier]`에서 `placeId`를 뺀 목록으로 이진 탐색, 최종 삽입 위치를 `rankIndex`로 전송
5. `submitReview` 호출. `ocr_unavailable`이면 입력 보존 후 재시도 버튼

직접 쓰기: `reviews/{reviewId}/likes/{myUid}` 에 `{createdAt: serverTimestamp()}` 생성/삭제, `reports` 생성 `{reviewId, reporterUid, reason(≤200자), createdAt}`.

읽기: 홈 = `restaurants where region == X orderBy realScore|bubble desc`, 상세 후기 = `reviews where restaurantId == X orderBy likeCount|createdAt desc`, 대마왕 배너 = `crowns where displayMonth == 이번달 && status == 'confirmed'`.
