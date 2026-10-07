# 로컬에서 앱 돌려보기 (Chrome + Firebase Emulator)

키·실서버 없이 전체 흐름(로그인 → 목록 → 상세 → 후기 작성 → 따봉·신고 → 프로필)을 볼 수 있다.
카카오 검색과 영수증 OCR은 에뮬레이터에서 기본 **가짜**로 동작한다(검색은 아래 "진짜 식당 검색 켜기"로 진짜로 바꿀 수 있다) (영수증은 어떤 사진이든 선택한 식당의 영수증으로 인정).

## 준비 (1회)
- Flutter SDK (`C:\src\flutter`, PATH 등록됨 — **새 터미널**을 열어야 `flutter`가 잡힌다), Chrome, Node 22+
- JDK 21 (`C:\Program Files\Java\jdk-21` 이거나 환경변수 `JAVA21_HOME`). 시스템 기본 java가 11이어도 `emu` 스크립트가 알아서 21을 쓴다
- 저장소 루트(`D:\zh-project`)에서:
```powershell
npm --prefix functions install
npm --prefix functions run build
npm --prefix functions run dev:setup
cd app; flutter pub get; cd ..
```

## 진짜 식당 검색 켜기 (선택, 카카오 REST 키 필요)
기본값은 가짜 식당 6곳만 나온다. 실제 가게를 찾으려면 카카오 로컬 API 키를 넣는다. (영수증 인식은 계속 가짜라서 아무 사진이나 통과한다.)

1. https://developers.kakao.com → 내 애플리케이션 → 애플리케이션 추가
2. 앱 → 앱 키 → **REST API 키** 복사 (제품 설정에서 **카카오맵** 사용 설정이 꺼져 있으면 켠다)
3. 저장소 루트에서 (키는 `functions/.secret.local` 에만 저장되고 git 에는 올라가지 않는다)
```powershell
npm --prefix functions run dev:setup -- --kakao-key=여기에_REST_키
```
4. 에뮬레이터를 다시 시작한다 (`emu` 또는 `emu:lan`). 이미 켜져 있었다면 껐다 켠다.
5. 앱에서 `후기 쓰기` → `화곡 국밥` 같은 이름으로 검색 → 실제 가게가 거리순으로 나온다.
   화곡동(강서구) 가게만 선택할 수 있고, 다른 지역은 `베타 지역 아님`으로 표시된다.

가짜 검색으로 되돌리려면 `npm --prefix functions run dev:setup` (키 없이) 후 에뮬레이터를 다시 시작한다.
> REST 키는 채팅·이슈·커밋에 붙여 넣지 않는다. 노출됐다면 카카오 콘솔에서 키를 재발급한다.

## 실행 (터미널 3개)
```powershell
# 터미널 A — 에뮬레이터 (Auth 9099 / Functions 5001 / Firestore 8080 / Storage 9199 / UI 4000)
npm --prefix functions run emu

# 터미널 B — A가 "All emulators ready" 를 찍은 뒤, 데모 데이터 주입
npm --prefix functions run seed

# 터미널 C — 앱 (Chrome이 열린다)
cd app
flutter run -d chrome --dart-define=USE_EMULATOR=true
```
에뮬레이터 UI: http://localhost:4000 (DB·가입자 확인, `crowns`·`reports` 확인 가능)

> 함수 코드를 고치면 `npm --prefix functions run build` 후 터미널 A를 다시 띄운다.
> 에뮬레이터를 껐다 켜면 데이터가 사라지므로 `seed`를 다시 실행한다.
> 앱 실행 중 코드를 고치면 터미널 C에서 `r`(핫리로드), `R`(핫리스타트).

## 수동 점검 체크리스트
1. **로그인**: 닉네임(예: `내가씀`) → 테스트 로그인 → 홈으로 이동. 새로고침해도 로그인 유지.
2. **홈**: 화곡 식당 4곳. `화곡 찐국밥 찐 7.8`, `화곡 찐고기 찐 2.3 · 이벤트 10.0 · 거품 +7.7`. `거품 큰 순`을 누르면 찐고기가 맨 위. 상단에 `👑 이번 달 찐후기 대마왕 · 찐미식가` 배너 → 누르면 그 유저 프로필.
3. **상세**: 식당 하나 → 후기 3개, 이벤트 참여 후기에 🎁 라벨. 따봉순/최신순 전환.
4. **따봉 제한**: 방금 가입한 계정으로 남의 후기 따봉 → "영수증 인증 후기를 1개 이상 쓰면…" 안내.
5. **후기 작성** (`화곡 찐빵집`은 후기가 없는 식당):
   `후기 쓰기` → `찐빵` 검색 → 선택 → 아무 이미지로 영수증 선택 → 등급 `최고` → (비교 없음) → 이벤트 켜고 별 5 → 한줄평 10자 이상 → 제출.
   → 상세로 이동, 내 후기가 보임. 홈에서 `찐빵집`은 후기 3개 미만이라 `찐 데이터 부족`.
6. **따봉 가능해짐**: 5번 이후 남의 후기에 따봉 → 숫자가 오르고 (잠시 뒤) 작성자 프로필의 `받은 따봉` 증가.
7. **본인 후기 따봉 불가**: 내 후기의 따봉 버튼이 회색.
8. **재방문**: 같은 식당에 후기를 다시 쓰면 덮어써지고 후기 수는 그대로. 영수증은 파일마다 다른 영수증으로 취급된다.
9. **베타 밖**: `찐돈까스` 검색 → `베타 지역 아님`으로 선택 불가.
10. **비교 질문**: 후기를 2~3개 더 쓰고(다른 식당, 같은 등급) 새 식당을 쓸 때 "○○와(과) 비교해 주세요" 질문이 나오고 답에 따라 내 리스트 순위가 바뀐다 (프로필 → 내 리스트).
11. **신고**: 후기의 깃발 → 사유 입력 → 에뮬레이터 UI의 `reports`에 문서 생김.
12. **로그아웃**: 내 프로필 → 로그아웃 → 로그인 화면으로 이동.

## 막힐 때
- `flutter` 를 못 찾음: 새 PowerShell/터미널을 연다. (또는 `$env:Path += ';C:\src\flutter\bin'`)
- 에뮬레이터가 Java 오류로 안 뜸: firebase-tools 14+ 는 JDK 21 필요. `JAVA21_HOME` 에 JDK 21 경로를 지정한다.
- 앱 화면이 비어 있음: 터미널 B(seed)를 실행했는지, 브라우저 콘솔에 `permission-denied` 가 없는지 확인.
- `FirebaseFunctionsException: INTERNAL`: 터미널 A 로그를 확인. 시크릿 관련이면 `npm --prefix functions run dev:setup` 후 에뮬레이터 재시작.
- 포트가 이미 사용 중: 이전 에뮬레이터가 남아 있다. 4000·5001·8080·9099·9199 를 쓰는 프로세스를 종료한다.
