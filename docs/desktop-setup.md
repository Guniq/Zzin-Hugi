# 다른 컴퓨터에서 실행하기

저장소: https://github.com/Guniq/Zzin-Hugi (작업 브랜치 `feat/kakao-login`)

## 0. 먼저 설치할 것

| 도구 | 버전 | 비고 |
|---|---|---|
| Git | 최신 | |
| Node.js | 20 이상 (24에서 확인) | |
| JDK | **21** | Firebase 에뮬레이터용. 기본 java 가 11이면 `functions/scripts/with-java21.js` 가 경로를 `C:\Program Files\Java\jdk-21` 로 찾는다. 다른 경로면 이 파일을 확인 |
| Flutter | 3.47.6 (Dart 3.13.5) | `flutter doctor` 로 확인. PATH 에 `flutter\bin` 등록 |
| Chrome | 최신 | 웹으로 확인 |

## 1. 받기

```powershell
git clone https://github.com/Guniq/Zzin-Hugi.git
cd Zzin-Hugi
git checkout feat/kakao-login
```

## 2. 비밀 키 파일 옮기기 (git 에 없음)

기존 PC 의 프로젝트 루트에서 USB·메신저 등으로 **직접** 복사해 새 PC 의 저장소 루트에 둔다. 커밋·채팅에 붙여 넣지 않는다.

- `restapi-key.txt` — 카카오 REST API 키
- `login-key.txt` — 카카오 로그인 Client Secret
- `kakao-js-key.txt` — 카카오맵 JavaScript 키
- (`api-key.txt` 는 Admin 키라 쓰지 않는다)

키가 없으면 가짜 검색(데모 식당 6곳)·지도 없는 목록 검색으로만 동작한다.

## 3. 설치·빌드 (저장소 루트에서, 1회)

```powershell
npm --prefix functions install
npm --prefix functions run build
npm --prefix functions run dev:setup -- --kakao-key=<restapi-key.txt 내용> --kakao-secret=<login-key.txt 내용>
cd app; flutter pub get; cd ..
```

키 없이 가짜 모드로만 볼 거면 `dev:setup` 에 옵션을 주지 않는다.

## 4. 실행 (터미널 3개, 모두 저장소 루트)

```powershell
# 터미널 A — 에뮬레이터 (켜 둔 채로 둔다)
npm --prefix functions run emu

# 터미널 B — A 가 뜬 뒤 데모 데이터
npm --prefix functions run seed

# 터미널 C — 웹 빌드 후 서빙
npm --prefix functions run build:web -- --host=localhost
npm --prefix functions run serve:web
```

브라우저에서 http://localhost:5050 . 에뮬레이터 UI 는 http://localhost:4000 .
에뮬레이터를 껐다 켜면 데이터가 사라지니 `seed` 를 다시 실행한다.

## 5. 카카오 콘솔 설정 (새 PC 주소가 같으면 생략)

주소가 `localhost:5050` 이면 기존 설정 그대로 쓴다. 다른 주소(PC IP 등)로 열 때만 추가한다.

- [앱]→[플랫폼 키]→[JavaScript 키]→**JavaScript SDK 도메인**: `http://localhost:5050`
- REST API 키 페이지 **Redirect URI**: `http://localhost:5050/` (끝 `/` 포함)
- 카카오 로그인 동의항목: **닉네임** 켜기

## 6. 알아둘 점

- 에뮬레이터 모드에서는 새로고침하면 로그인이 풀리고 마지막 테스트 닉네임으로 자동 재로그인된다.
- "내 위치" 버튼은 http 접속에서 브라우저가 막는다.
- 서버 테스트(`test:unit`, `test:emu`)는 옛 등급 방식 기준이라 일부가 실패한다. 앱 실행에는 영향 없다.
- 포트: 4000 / 5001 / 5050 / 8080 / 9099 / 9199. `port taken` 이면 남은 프로세스를 종료한다.
- 안드로이드 에뮬레이터는 PC 사양 때문에 포기했다. 쓰려면 `--dart-define=EMULATOR_HOST=10.0.2.2`.
