# 찐후기 — 설계 스펙

- 작성일: 2026-10-07
- 상태: 사용자 검토 대기

## 1. 배경과 목표

리뷰 이벤트(음료 증정 → 별점 5점)로 네이버·배민 등 기존 별점이 오염됨. "찐후기"는 이벤트 참여 여부와 무관하게 **영수증으로 방문을 인증한 사람의 솔직한 평가**를 모으고, 이벤트 별점과 실제 평가의 차이(**거품지수**)를 보여주는 맛집 후기 앱.

**성공 기준 (베타)**
- 베타 지역 내 식당 다수가 "데이터 부족"을 벗어남 (후기 3개 이상)
- 거품지수가 실제 식당 선택에 쓰이는 정보로 인식됨 (베타 사용자 인터뷰로 확인)

## 2. 경쟁·벤치마킹 요약

| 앱 | 관계 |
|---|---|
| 네이버 지도/플레이스 | 직접 경쟁, 오염 리뷰의 주 무대 |
| 카카오맵 | 간접 경쟁, 식당 데이터 소스로 활용(카카오 로컬 API) |
| 다이닝코드 | 가장 가까운 경쟁자. 광고 블로그를 알고리즘으로 필터링 (사용자 인증 아님) |
| 캐치테이블 | 예약자만 리뷰 → 방문 인증 벤치마킹 |
| Beli (해외) | 별점 대신 비교형 랭킹 → 평가 방식 벤치마킹 |

차별점: **이벤트 참여 자기신고 + 영수증 인증 + 거품지수**. 동일 콘셉트 국내 앱은 1차 조사에서 미발견 (출시 전 앱스토어 재확인 필요).

## 3. 범위

### 3.1 확정 결정
- 플랫폼: **Flutter + Firebase** (iOS/Android 동시)
- 출시: **지역 한정 베타** (1~2개 동네, 예: 성수·강남). 지역은 `region` 필드 값으로 관리, 베타 지역 목록은 Firestore `config/regions` 문서
- 식당 데이터: **카카오 로컬 API** (자체 DB 구축 안 함, 조회된 식당만 `restaurants`에 저장)
- 검증 방식: 영수증 인증 + 이벤트 참여 여부 표기 + 비교형 평가

### 3.2 화면 (6개)
1. **로그인** — 카카오 로그인, Apple 로그인
2. **홈 (지도 + 목록)** — 베타 지역 식당, 찐점수·거품지수 배지, 정렬(찐점수순 / 거품 큰 순), "이번 달 대마왕" 배너
3. **식당 상세** — 찐점수, 이벤트 점수 평균, 거품지수, 후기 목록(이벤트 참여 후기 🎁 라벨, 작성자 칭호, 따봉 버튼), 정렬(따봉순 / 최신순), 신고 버튼
4. **후기 작성**
   1. 카카오 장소 검색으로 식당 선택
   2. 영수증 촬영 → OCR 검증
   3. 1차 평가: 최고 / 괜찮 / 별로
   4. 2차 비교: 같은 등급 내 기존 식당과 "어디가 더 나았나?" (이진 삽입, 최대 ⌈log2(n+1)⌉회)
   5. "리뷰 이벤트 참여했나요?" → 예: "몇 점 줬나요? (1~5)"
   6. 한줄평(필수, 10~300자), 사진(선택, 최대 5장)
5. **내 리스트** — 내가 평가한 식당 순위표
6. **프로필** — 칭호, 받은 따봉 수, 해당 유저의 리스트

### 3.3 MVP 제외 (v2 이후)
팔로우/피드, 사장님 답글, 광고·결제, 푸시 알림, 관리자 웹(Firebase 콘솔로 대체), 따봉 담합 자동 탐지.

## 4. 점수 정의

| 점수 | 정의 |
|---|---|
| 개인 점수 | 등급 구간(최고 7~10 / 괜찮 4~7 / 별로 0~4) 안에서 순위로 선형 보간. 등급 내 n개 중 i번째(0=최상) → `hi - (hi-lo) * (i + 0.5) / n`. 소수점 1자리 |
| 찐점수 | 해당 식당 인증 후기 개인 점수 평균 (0~10) |
| 이벤트 점수 | 이벤트 참여 후기의 자기신고 별점 평균 × 2 (0~10 환산) |
| 거품지수 | 이벤트 점수 − 찐점수 |

표시 조건:
- 찐점수: 후기 3개 이상, 미만이면 "데이터 부족"
- 거품지수: 이벤트 참여 후기 3개 이상

새 식당을 등급에 삽입하면 같은 등급 내 다른 식당의 개인 점수도 변함 → `submitReview`가 해당 유저의 영향받는 후기와 그 식당 집계를 재계산.

## 5. 따봉과 칭호

**따봉 규칙**
- 후기당 1인 1따봉, 취소 가능. 비추천 없음
- 본인 후기 따봉 불가
- 인증 후기 1개 이상 보유자만 따봉 가능
- 따봉은 찐점수 계산에 반영하지 않음 (점수와 평판 분리)

**칭호** (누적 받은 따봉)

| 칭호 | 조건 |
|---|---|
| 찐린이 | 가입 |
| 찐후기러 | 따봉 10+ |
| 찐고수 | 따봉 50+ |
| 👑 찐후기 대마왕 | 월간 지역별 받은 따봉 1위 (매월 1일 갱신, 운영자 확인 후 확정) |

대마왕 칭호는 해당 월 동안 표시되며, 종료 후 누적 따봉 기준 칭호로 복귀.

## 6. 아키텍처

```
Flutter 앱 (Riverpod, 기능별 폴더)
   ├─ Firebase Auth ── 카카오: Cloud Function 커스텀 토큰 / Apple: 네이티브
   ├─ Firestore ────── 읽기: 앱 직접 / 쓰기: 따봉·신고 외 전부 Function 경유
   ├─ Storage ──────── receipts/ (비공개, 30일 후 삭제), photos/ (공개 읽기)
   └─ Cloud Functions (TypeScript)
        ├─ kakaoLogin      카카오 액세스 토큰 검증 → Firebase 커스텀 토큰
        ├─ searchPlaces    카카오 로컬 API 프록시 (REST 키 서버 보관)
        ├─ submitReview    OCR → 검증 → 순위 반영 → 집계 (트랜잭션)
        ├─ onLikeWrite     후기 likeCount, 작성자 likesReceived·칭호 갱신
        └─ monthlyCrown    매월 1일 지역별 대마왕 후보 선정 (pending 상태)
```

외부 서비스: 카카오 로그인, 카카오 로컬 API, 네이버 CLOVA OCR(영수증 특화 모델), 지도 SDK(`flutter_naver_map` 기본, 플랜 단계에서 확인).

## 7. 데이터 모델 (Firestore)

| 경로 | 필드 |
|---|---|
| `users/{uid}` | nickname, title, likesReceived, verifiedReviewCount, ranking `{best: [placeId], ok: [...], bad: [...]}`, dailyReviewCount, dailyReviewDate, createdAt |
| `restaurants/{kakaoPlaceId}` | name, address(지번), roadAddress, lat, lng, geohash, region(베타 지역 밖이면 null), scoreSum, reviewCount, eventStarSum, eventReviewCount, realScore, eventScore, bubble. 서버(`searchPlaces`)만 생성 |
| `reviews/{uid}_{placeId}` | uid, restaurantId, region, tier, personalScore, eventJoined, eventStars(nullable), text, photos[], visitDate, likeCount, createdAt, updatedAt |
| `reviews/{id}/likes/{uid}` | createdAt |
| `receiptKeys/{hash}` | uid, reviewId, createdAt. hash = SHA-256(승인번호+금액+날짜) |
| `reports/{id}` | reviewId, reporterUid, reason, createdAt |
| `crowns/{표시월 yyyy-MM}_{region}` | uid, likes, region, scoreMonth(집계월), displayMonth(표시월), status(pending/confirmed) |
| `likeMonths/{yyyy-MM}_{region}_{uid}` | uid, region, month, likes — 월간 지역별 받은 따봉 (대마왕 집계용) |
| `searchCache/{hash}` | placeIds, cachedAt — 카카오 검색 결과 7일 캐시 |
| `config/regions` | list: `[{id, name, gu, dongs[]}]` 예: `{id:'seongsu', name:'성수', gu:'성동구', dongs:['성수']}` |

보안 규칙:
- `restaurants`, `reviews`, `users`, `crowns`: 클라이언트 읽기 전용
- `likes`: 생성/삭제 허용 조건 — 인증됨, 문서 ID = 본인 uid, 본인 후기 아님, `users/{uid}.verifiedReviewCount >= 1`
- `reports`: 생성만 허용, reporterUid = 본인
- `receiptKeys`, `config`, `likeMonths`, `searchCache`: 클라이언트 접근 불가

유저 문서 생성: 로그인 직후 앱이 `ensureUser` callable 호출 (카카오·Apple 공통).
베타 지역 밖 식당은 후기 작성 거절 (`out_of_region`).

## 8. 어뷰징 방어

| 공격 | 방어 |
|---|---|
| 가짜/타 가게 영수증 | OCR 상호명 ↔ 카카오 장소명 유사도(공백·법인표기 제거 후 포함 관계 또는 편집거리 기준), 주소 구·동 일치, 방문일 30일 이내 |
| 영수증 재사용 | `receiptKeys` 해시 중복 거절 |
| 한 식당 도배 | 유저당 식당 1후기. 재방문 시 새 영수증으로 기존 후기 갱신 |
| 부계정 대량 작성 | 소셜 계정 기반 + 하루 후기 5개 제한 |
| 이벤트 점수 허위 신고 | 거품지수는 이벤트 후기 3개 이상일 때만 표시 |
| 따봉 담합 | 인증자만 따봉 + 대마왕은 운영자 확인 후 확정 |
| 사장님 자작 | 신고 → 콘솔 처리. 완벽 차단 불가, 비용 상승에 집중 |

## 9. 에러 처리

- OCR 실패·타임아웃: 작성 중 후기 로컬 임시저장 + 재시도. 입력 내용 보존
- 영수증 검증 실패: 실패 사유(상호 불일치 / 날짜 초과 / 중복 / 판독 불가) 표시, 재촬영 안내
- `submitReview` 실패: 트랜잭션 전체 롤백 (영수증 해시 미등록)
- 카카오 API 쿼터 절약: 같은 검색어+위치(소수 2자리) 결과를 `searchCache`에 7일 캐시
- 오프라인: 읽기는 Firestore 캐시, 작성은 온라인 필수

## 10. 테스트

- 점수 계산(개인 점수 보간, 찐점수, 거품지수): 순수 함수, Jest 단위 테스트
- 영수증 매칭: 실제 OCR 결과 JSON 샘플 10여 개 fixture
- 보안 규칙: Firebase Emulator + `@firebase/rules-unit-testing`
- Flutter: 후기 작성 흐름 위젯 테스트
- 개발 환경: Firebase Emulator Suite. E2E는 베타 수동 QA

## 11. 개인정보

- 영수증 원본은 검증 후 30일 뒤 자동 삭제 (Storage 수명 주기 규칙)
- 영수증에서 추출한 필드 중 해시와 방문일만 보관, 카드번호 등은 저장하지 않음
- 출시 전 개인정보 처리방침에 영수증 수집·보관 기간 명시
