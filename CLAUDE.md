# 찐후기 (ZzinHugi) — 프로젝트 인수인계

리뷰 이벤트(음료 증정 → 별점 5점)로 오염된 맛집 후기를 걸러내는 앱. **영수증으로 방문을 인증**한 사람의 후기만 모으고,
이벤트 별점과 실제 평가의 차이(**거품지수**)를 보여 준다. 영문 이름은 **ZzinHugi** (식별자는 `zzinhugi`).

## 작업 규칙 (사용자 지시 — 반드시 지킨다)

1. **구현을 마친 뒤 테스트·빌드·브라우저 점검을 실행하지 않는다.** 변경한 내용과 확인이 필요한 부분만 보고하고,
   검증은 사용자가 한다. (기존 테스트 파일은 그대로 두고, 요청받기 전에는 돌리지 않는다. 테스트를 돌리지 않았다는 사실을 보고에 분명히 적는다.)
   **대신 수정하면 서빙한다:** 사용자는 `http://localhost:5050` 에서 직접 확인한다. 코드를 바꾼 뒤에는
   - `app/web/*` 만 바뀌었으면 `app/build/web/` 로 **파일만 복사**하고(`cp app/web/kakao_map.js app/build/web/`),
   - `app/lib/*` 가 바뀌었으면 `npm --prefix functions run build:web -- --host=localhost` 로 웹을 다시 만들고(서빙용 빌드는 점검이 아님),
   - `functions/src/*` 가 바뀌었으면 `npm --prefix functions run build` 후 에뮬레이터를 다시 띄운다(데이터가 사라지므로 `seed` 다시).
   그리고 에뮬레이터(`emu`)·`seed`·`serve:web` 을 **켜 둔 채로 두고 끄지 않는다.** 이미 떠 있으면 다시 띄우지 않는다(포트 4000/5001/5050/8080/9099/9199 확인).
2. 모든 응답은 **한글**로 쓴다 (코드·커밋 메시지·기술 용어는 원문 가능).
3. **비밀값**(`restapi-key.txt`=카카오 REST API 키, `login-key.txt`=카카오 로그인 Client Secret, `kakao-js-key.txt`=지도용 JavaScript 키,
   `functions/.secret.local`)은 (`api-key.txt` 는 **Admin 키라서 쓰지 않는다** — 카카오 로그인에서 KOE008) 출력·채팅·커밋에 노출하지 않는다. 모두 git 무시 대상이다.
4. 방화벽·PATH 같은 **시스템 보안 설정은 직접 바꾸지 않고** 명령만 안내한다. 큰 다운로드·전역 설치는 먼저 묻는다.
5. 큰 기능은 **디자인 캔버스에서 먼저 확인받고** 구현한다 (아래 "디자인").

## 현재 상태 (마지막 정리 시점)

- 브랜치는 `master → feat/backend → feat/app → feat/real-search → feat/hwagok → feat/map-search` 로 쌓여 있고, **master 에는 아직 합치지 않았다.**
  최신은 `feat/map-search`. 합치기 전에 사용자 확인이 필요하다.
- 구현 완료: 로그인(에뮬레이터 테스트 로그인), 홈(식당 목록·정렬·대마왕 배너), 식당 상세(거품 게이지·후기·따봉·신고),
  후기 작성 6단계(식당 찾기→영수증→등급→비교→이벤트→한줄평), 프로필, 월간 대마왕 선정, **카카오 실제 식당 검색**, **카카오맵 지도 검색**.
- 마지막으로 돌려 본 결과(참고용, 이후 변경분은 미검증): Flutter 85개, 백엔드 단위 83개, 에뮬레이터 49개 통과.
  카카오맵 검색→핀→선택→영수증 단계는 브라우저로 확인했다. **그 뒤 변경(문서, 지도 관련 마무리)은 테스트하지 않았다.**
- 베타 지역: **화곡동(서울 강서구)**, 지역 ID `hwagok`. 지역 정의는 앱 `app/lib/core/regions.dart` 와 서버 `config/regions` 문서 두 곳.

## 아직 안 된 것 / 다음 할 일

1. **카카오 로그인(웹)은 구현했고 사용자 확인 대기 중**: 인가 코드 방식. 앱이 `kakaoLoginUrl` 로 카카오 주소를 받아 이동 → `http://localhost:5050/?code=…` 로 복귀 →
   `kakaoLogin({code, redirectUri})` 이 토큰 교환 후 Firebase 커스텀 토큰 발급(`signInWithCustomToken`). `state` 로 CSRF 확인. 카카오 콘솔의 **Redirect URI**(`http://localhost:5050/`, 끝 `/` 포함)와
   동의항목(닉네임) 등록이 필요하고, Client Secret 을 켰으면 `dev:setup --kakao-secret=` 로 넣는다. 에뮬레이터 모드에서는 새로고침하면 로그인이 풀린다. **Apple 로그인은 아직 없다.**
   키가 없을 때는 `FAKE_KAKAO` 가짜 로그인(`fakeAuthorizeUrl` 등)으로 흐름만 확인한다.
2. **실서버 연결/배포**: 실제 Firebase 프로젝트, `flutterfire configure`, `firebase_options.dart`, `config/regions` 문서, 시크릿(`firebase functions:secrets:set`). 지금 앱은 `--dart-define=USE_EMULATOR=true` 없이는 시작하지 않는다.
3. **CLOVA OCR**: 응답 필드 경로(`confirmNum`, `addresses`)가 **공식 문서로 미검증**. 실제 영수증 10장을 `functions/test/fixtures/clova/` 에 넣어 파서를 확인해야 한다. 지금 에뮬레이터의 영수증 인식은 가짜(아무 사진이나 통과).
4. **네이티브 앱**: iOS는 Mac/클라우드 빌드 + Apple Developer 가입이 필요. 모바일 지도는 웹과 다른 SDK로 `kakao_place_map_stub.dart` 자리에 새로 만들어야 한다.
5. 앱 아이콘·스토어 등록·개인정보 처리방침.

## 구조

```
CLAUDE.md                 이 문서
firebase.json             에뮬레이터/배포 설정 (firebase.lan.json = 폰 접속용 0.0.0.0 바인딩)
firestore.rules, storage.rules, firestore.indexes.json
functions/                Cloud Functions (TypeScript, Jest)
  src/scoring.ts          개인 점수·순위 삽입·찐점수·거품지수 (순수 함수)
  src/receipt.ts          영수증 검증(상호·주소·날짜·해시)   src/address.ts 지역 판정
  src/search.ts           searchPlaces (카카오 검색 + 100m 단위 캐시 + 기본 위치)
  src/review.ts           submitReview (OCR→검증→순위→집계 트랜잭션)
  src/auth.ts             kakaoLogin, ensureUser          src/likes.ts 따봉 집계   src/crown.ts 월간 대마왕
  src/dev/                에뮬레이터 전용 가짜 검색·OCR(fake.ts), 데모 데이터(seed.ts)
  scripts/                dev-setup.js(.env.local/.secret.local 생성), with-java21.js
app/                      Flutter (웹 우선, Riverpod, go_router)
  lib/domain/             점수 표기·이진 비교 순위(ranking_session)·오류 문구·모델
  lib/data/               Backend 인터페이스(FirebaseBackend), AuthService
  lib/features/           login, home, restaurant, write(+map/), profile
  lib/ui/                 theme, gauge(거품 게이지), widgets
  web/kakao_map.js        카카오맵 JS SDK 래퍼 (window.zzinMap)
  assets/fonts/           Noto Sans KR 4굵기(부분 포함)
scripts/                  build-fonts.py, build-web.js, serve-web.js
docs/                     run-local.md, iphone-test.md, deploy.md, superpowers/{specs,plans}/
```

## 실행 (자세한 건 docs/run-local.md, docs/iphone-test.md)

모든 `npm --prefix functions ...` 는 **저장소 루트(`D:\zh-project`)에서** 실행한다. `flutter` 만 `app/` 에서.

```powershell
npm --prefix functions run build && npm --prefix functions run dev:setup   # 1회 (키: -- --kakao-key=...)
npm --prefix functions run emu          # 터미널 A: 에뮬레이터 (폰 접속용은 emu:lan)
npm --prefix functions run seed         # 터미널 B: 데모 데이터
npm --prefix functions run build:web -- --host=localhost   # 웹 빌드 (kakao-js-key.txt 있으면 지도 켜짐)
npm --prefix functions run serve:web    # → http://localhost:5050
```
`dev:setup` 에 `--kakao-key=<REST키>` 를 주면 식당 검색만 진짜 카카오, 영수증 인식은 가짜. 키 없이 실행하면 둘 다 가짜(데모 식당 6곳).

## 핵심 결정과 이유

- **영수증 인증 + 이벤트 참여 자기신고 + 비교형 평가**. 별점 대신 같은 등급 안에서 이진 비교로 순위를 정한다(`ranking_session`).
  개인 점수: 최고 7~10 / 괜찮 4~7 / 별로 0~4, 순위로 보간. 찐점수=인증 후기 평균, 거품=이벤트점수−찐점수, 3개 미만이면 "데이터 부족".
- **후기 쓰기는 서버 함수 경유만**(클라이언트 직접 쓰기 금지). 따봉·신고만 클라이언트가 직접 쓰고 보안 규칙으로 막는다.
- **에뮬레이터 전용 가짜 모드**: `FAKE_EXTERNALS=true` 이고 `FUNCTIONS_EMULATOR=true` 일 때만 켜진다(실서버에서는 절대 안 켜짐). 검색은 `FAKE_KAKAO=false` 로 따로 진짜로 바꾼다.
- **Firebase JS SDK 웹 에뮬레이터 문제**: 저장된 세션 복원이 에뮬레이터 연결보다 먼저 실서버로 나가 로그인이 풀린다. 그래서 에뮬레이터 모드에서는
  시작 시 저장된 인증 IndexedDB 를 지우고(`reset_auth_store`) 마지막 테스트 닉네임으로 자동 재로그인한다(`restoreDebugSession`). 실서버에서는 해당 없음.
- **한글 글꼴을 앱에 포함**: 웹에서 글꼴이 늦게 내려오면 칩 글자 폭이 잘못 계산돼 잘린다.
- 에뮬레이터 연결 시 SDK가 띄우는 빨간 배너는 `web/index.html` 에서 CSS로 숨겼다(버튼을 가렸음).
- **지도는 카카오맵 JS SDK(웹 전용)**. Dart 는 `place_map_types.dart` 의 `PlaceMapBuilder` 만 보고, 웹 구현은 `kakao_place_map_web.dart`+`web/kakao_map.js`,
  테스트는 `test/fake_map.dart` 가짜 지도로 바꿔 끼운다. 키(`kakaoJsKey`)가 없거나 웹이 아니면 지도 대신 목록 검색이 기본.
  "내 위치"는 http 접속에서는 브라우저가 막는다(https 필요).
- 지도 JS 키는 카카오 콘솔 [앱]→[플랫폼 키]→[JavaScript 키]→[JavaScript SDK 도메인] 에 접속 주소를 등록해야 한다(`localhost:5050`, 폰이면 `<PC IP>:5050`).

## 환경 주의 (Windows)

- Flutter SDK: `C:\src\flutter` (사용자 PATH 등록, 새 터미널 필요). **JDK 21** `C:\Program Files\Java\jdk-21` — firebase-tools 15 에뮬레이터에 필요하며 `with-java21.js` 가 PATH 앞에 붙여 준다(기본 java 는 11).
- Git Bash 에서 **큰 heredoc 이 파싱 오류**를 내는 경우가 있다. 긴 파일은 Write/Edit 도구로 쓴다. 한글 문자열에 `\n` 을 넣을 때 python heredoc 으로 편집하면 실제 줄바꿈이 들어가 깨진다.
- 에뮬레이터를 파이프로 `grep` 하면 프로세스가 남아 다음 실행에서 `port taken` 이 난다. 로그 파일로 돌리고, 끝나면 4000/4400/5001/5050/8080/9099/9199 포트를 쓰는 프로세스를 종료한다.
- Node 24 에서 `MetadataLookupWarning` 이 나오지만 무해하다.
- 에뮬레이터 포트: Auth 9099 / Functions 5001 / Firestore 8080 / Storage 9199 / UI 4000.

## 디자인

Claude 디자인 캔버스(Artifact): https://claude.ai/artifact/5eXiboxmggopR5U9vMGwPz — 화면 9개(로그인·홈·상세·식당 찾기(지도/목록)·영수증·비교·이벤트·프로필).
색: 먹색 `#121417`, 포인트 `#C93C1C`, 바탕 `#F3F4F6`. 핵심 시각 요소는 **거품 게이지**(찐점수=채운 점, 이벤트 점수=빈 점, 사이=줄무늬).
디자인을 바꾸면 캔버스를 먼저 고쳐 확인받는다. 캔버스는 페이지에서 사용자가 직접 수정할 수 있어서, 올리기 전에 최신본을 읽어 병합한다.

## 문서

- 설계: `docs/superpowers/specs/2026-10-07-zzinhugi-design.md`
- 구현 플랜: `docs/superpowers/plans/2026-10-07-zzinhugi-backend.md` (플랜 1), `...-app.md` (플랜 2). 플랜 3(카카오 로그인·실서버·네이티브)은 아직 쓰지 않았다.
- 실행: `docs/run-local.md` / 아이폰 테스트: `docs/iphone-test.md` / 배포: `docs/deploy.md`
