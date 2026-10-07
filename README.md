# 찐후기 (ZzinHugi)

> 리뷰 이벤트 말고, **영수증으로 확인한 찐 후기.**

음료를 주고 별점 5점을 받는 리뷰 이벤트 때문에 맛집 별점이 오염됐다는 문제의식에서 출발한 맛집 후기 앱입니다.
방문을 **영수증으로 인증**한 사람만 후기를 쓸 수 있고, 이벤트로 준 별점과 실제 평가의 차이를 **거품지수**로 보여 줍니다.

현재는 **서울 강서구 화곡동**에서 시작하는 베타 단계이며, 로컬 개발 환경(Firebase 에뮬레이터)에서 동작합니다.

## 핵심 아이디어

| | |
|---|---|
| **영수증 인증** | 영수증을 올려 상호·주소·날짜(30일 이내)·중복 사용 여부를 서버에서 확인합니다. 원본은 30일 뒤 삭제됩니다. |
| **별점 비교** | 실제 별점(1~5)을 매기고, 이벤트에 참여했다면 이벤트 때 준 별점도 함께 매겨 두 값을 나란히 비교합니다. 같은 사람의 두 별점 차이로 거품을 계산해 공정합니다. |
| **이벤트 참여 표기** | "리뷰 이벤트에 참여했나요? 몇 점 줬나요?"를 솔직하게 받습니다. 이 값은 찐점수에 섞이지 않고 거품지수에만 쓰입니다. |
| **거품 게이지** | 찐점수(채운 점)와 이벤트 점수(빈 점) 사이를 줄무늬로 보여 줍니다. 간격이 클수록 거품이 큰 가게입니다. |
| **따봉과 칭호** | 인증 후기를 쓴 사람만 따봉을 줄 수 있고, 따봉에 따라 칭호가 오릅니다. 매월 지역별 1위가 **찐후기 대마왕**입니다. |

## 주요 기능

- 식당 목록(찐점수순 / 거품 큰 순), 식당 상세(점수·후기·따봉·신고), 내 리스트·프로필
- **카카오맵으로 식당 찾기** — 검색 결과를 핀으로 보고, 지도를 옮겨 "이 지역에서 다시 검색", 목록 보기 전환
- 후기 작성 6단계: 식당 찾기 → 영수증 → 등급 → 비교 → 이벤트 → 한줄평·사진
- 하루 5개 작성 제한, 같은 영수증 재사용 차단, 베타 지역 밖 식당 차단

## 기술 스택

- **앱**: Flutter (웹 우선, 이후 iOS·Android) · Riverpod · go_router
- **백엔드**: Firebase (Auth · Firestore · Storage · Cloud Functions, TypeScript)
- **외부 서비스**: 카카오 로컬 API(식당 검색) · 카카오맵 JavaScript SDK(지도) · 네이버 CLOVA OCR(영수증, 연결 예정)

## 빠르게 실행해 보기

필요한 것: Node 22+, JDK 21, Flutter SDK, Chrome. (Windows 기준 안내이며, 자세한 절차는 [docs/run-local.md](docs/run-local.md))

```powershell
# 저장소 루트에서 1회
npm --prefix functions install
npm --prefix functions run build
npm --prefix functions run dev:setup        # 키 없이 → 검색·영수증 인식 모두 가짜(데모 식당)
cd app; flutter pub get; cd ..

# 터미널 3개
npm --prefix functions run emu              # A: Firebase 에뮬레이터
npm --prefix functions run seed             # B: 데모 데이터 (A가 ready 된 뒤)
npm --prefix functions run build:web -- --host=localhost
npm --prefix functions run serve:web        # C: http://localhost:5050
```

브라우저에서 닉네임으로 테스트 로그인하면 전체 흐름(목록 → 상세 → 후기 작성 → 따봉 → 프로필)을 볼 수 있습니다.
에뮬레이터에서는 영수증 인식이 가짜라서 **아무 사진이나** 선택한 식당의 영수증으로 인정됩니다.

### 키를 넣으면 더 진짜에 가까워집니다 (선택)

| 키 | 효과 | 설정 |
|---|---|---|
| 카카오 **REST 키** | 식당 검색이 실제 카카오 데이터로 바뀜 | `npm --prefix functions run dev:setup -- --kakao-key=<키>` (콘솔에서 카카오맵 사용 설정 필요) |
| 카카오 **JavaScript 키** | 식당 찾기가 지도 화면으로 바뀜 | 루트의 `kakao-js-key.txt` 에 저장하고 접속 주소를 JavaScript SDK 도메인에 등록 → `build:web` 다시 실행 |

키 파일(`api-key.txt`, `kakao-js-key.txt`, `functions/.secret.local`)은 git 에 올라가지 않습니다. 키를 채팅이나 이슈에 붙여 넣지 마세요.

### 아이폰에서 테스트

같은 Wi-Fi에서 사파리로 접속하고 "홈 화면에 추가"하면 앱처럼 쓸 수 있습니다. 방화벽 설정과 Tailscale 사용법은 [docs/iphone-test.md](docs/iphone-test.md) 를 보세요.
(네이티브 iOS 앱은 Mac 또는 클라우드 빌드와 Apple Developer 가입이 필요합니다.)

## 폴더 구조

```
app/          Flutter 앱 (lib/features: login · home · restaurant · write · profile)
functions/    Cloud Functions + 점수 계산·영수증 검증·검색 + 에뮬레이터용 가짜 데이터
scripts/      웹 빌드·서빙, 글꼴 생성
docs/         실행 가이드, 설계 스펙, 구현 플랜
```

## 문서

| 문서 | 내용 |
|---|---|
| [docs/run-local.md](docs/run-local.md) | 로컬 실행, 지도·진짜 검색 켜기, 수동 점검 체크리스트 |
| [docs/iphone-test.md](docs/iphone-test.md) | 아이폰으로 테스트하는 방법(사파리 / 실서버 / TestFlight) |
| [docs/deploy.md](docs/deploy.md) | 실서버 배포 절차 |
| [docs/superpowers/specs/](docs/superpowers/specs/2026-10-07-zzinhugi-design.md) | 제품·시스템 설계 |
| [docs/superpowers/plans/](docs/superpowers/plans/) | 구현 플랜 |
| [CLAUDE.md](CLAUDE.md) | 작업 규칙과 인수인계 (현재 상태, 다음 할 일, 환경 주의) |

## 진행 상황

- [x] 점수·영수증 검증·후기 제출·따봉·대마왕 백엔드
- [x] 앱 전체 화면과 디자인 적용, 한글 글꼴 포함
- [x] 카카오 실제 식당 검색, 카카오맵 지도 검색
- [x] 화곡동 베타 지역
- [ ] 카카오 로그인·Apple 로그인 연결
- [ ] 실제 Firebase 프로젝트 연결과 배포 (https)
- [ ] CLOVA OCR 실제 영수증 검증
- [ ] 네이티브 앱(iOS·Android), 모바일 지도
- [ ] 개인정보 처리방침, 스토어 등록

## 주의

- 지금의 테스트 로그인·가짜 영수증 인식은 **개발용**입니다. 실서비스에서는 켜지지 않도록 에뮬레이터에서만 동작하게 막아 두었습니다.
- 지도의 "내 위치"는 브라우저 제한 때문에 https 주소에서만 동작합니다.
- 카카오·구글 등 외부 서비스 약관과 요금은 각 서비스 정책을 따릅니다.
