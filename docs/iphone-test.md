# 아이폰으로 테스트하기

앱을 아이폰에서 써 보는 방법은 세 가지다. 지금 바로 되는 것은 **A(같은 Wi-Fi + 사파리)** 뿐이고, B·C는 준비물이 더 필요하다.

| 방법 | 준비물 | 지금 가능? | 특징 |
|---|---|---|---|
| **A. 사파리로 접속 (홈 화면에 추가)** | 같은 Wi-Fi(또는 Tailscale), PC 켜 둠 | **가능** | 무료. 앱처럼 아이콘으로 실행. 에뮬레이터 데이터라 PC를 끄면 사라짐 |
| B. 실서버에 올리기 (Firebase Hosting) | Firebase 프로젝트(Blaze), 카카오·CLOVA 키 | 플랜 3 | 어디서나 https 주소로 접속, 진짜 영수증 인식 |
| C. 네이티브 iOS 앱 (TestFlight) | Mac + Xcode **또는** 클라우드 빌드(Codemagic 등), Apple Developer Program(연 $99) | 플랜 3 이후 | 카카오 SDK·푸시·카메라 등 네이티브 기능. 심사 없이 TestFlight로 설치 |

Windows PC에서는 iOS 앱을 직접 빌드할 수 없다(Xcode가 Mac 전용). 그래서 C는 Mac이나 클라우드 빌드가 필요하다.

---

## A. 같은 Wi-Fi에서 사파리로 접속

> 아이폰과 PC가 **같은 공유기**에 연결돼 있어야 한다. 밖(LTE)에서는 아래 "Tailscale" 절을 쓴다.

### 1) PC의 IP 확인
```powershell
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.*' } | Select-Object InterfaceAlias,IPAddress
```
Wi-Fi/이더넷 어댑터의 `192.168.x.x` 를 쓴다 (VMware·가상 어댑터는 제외). 아래에서는 `192.168.0.179` 로 적는다.

### 2) 방화벽 열기 (관리자 PowerShell, 1회)
방화벽이 수신을 막고 있어서 폰이 PC에 접속하지 못한다. **개인 네트워크(집 Wi-Fi)에만** 개발용 포트를 연다.
```powershell
New-NetFirewallRule -DisplayName "ZzinHugi dev (LAN)" -Direction Inbound -Protocol TCP `
  -LocalPort 5050,9099,8080,9199,5001 -Action Allow -Profile Private
```
테스트가 끝나면 닫는다:
```powershell
Remove-NetFirewallRule -DisplayName "ZzinHugi dev (LAN)"
```
> 에뮬레이터는 로그인 없이 DB를 읽고 지울 수 있다. 집 Wi-Fi처럼 믿을 수 있는 네트워크에서만 열고, 카페 등 공용 Wi-Fi에서는 쓰지 않는다.
> 네트워크 종류가 `공용(Public)` 이면 규칙이 적용되지 않는다. `Get-NetConnectionProfile` 로 확인하고, 집이면 `Set-NetConnectionProfile -InterfaceAlias "이더넷" -NetworkCategory Private`.

### 3) 서버 띄우기 (터미널 3개, 저장소 루트)
```powershell
# 터미널 A — 외부에서 접속 가능한 에뮬레이터 (0.0.0.0)
npm --prefix functions run emu:lan

# 터미널 B — A가 "All emulators ready" 를 찍은 뒤 데모 데이터
npm --prefix functions run seed

# 터미널 C — 폰이 접속할 PC 주소를 박아서 웹 빌드 후 서빙 (IP를 본인 것으로)
# (저장소 루트의 kakao-js-key.txt 가 있으면 지도 검색이 켜진다)
npm --prefix functions run build:web -- --host=192.168.0.179
npm --prefix functions run serve:web
```
`--host` 는 **앱이 에뮬레이터를 찾아갈 주소**라서 폰 입장에서 접속 가능한 PC의 IP여야 한다(`localhost` 는 폰 자신을 가리켜 안 된다). IP가 바뀌면 다시 빌드한다.

### 4) 아이폰에서
1. **사파리**에서 `http://192.168.0.179:5050` 접속 (크롬 등 다른 브라우저는 "홈 화면에 추가"가 제한적이다)
2. 닉네임을 넣고 `테스트 로그인`
3. 공유 버튼(□↑) → **홈 화면에 추가** → 이후에는 아이콘으로 앱처럼 실행된다
4. 영수증 단계에서 `영수증 사진 선택` → 사파리의 "사진 찍기 / 사진 보관함" 선택창이 뜬다. (에뮬레이터에서는 **어떤 사진이든** 그 식당의 영수증으로 인정된다)

### 알아둘 점
- 화면 아래 빨간 **"Running in emulator mode"** 배너는 Firebase 에뮬레이터 연결 표시다. 실서버에서는 나오지 않는다. 배너가 버튼 아래쪽을 가릴 수 있으니 화면을 살짝 올려서 누른다.
- 에뮬레이터를 끄면 데이터가 사라진다. 다시 켜면 `seed` 를 다시 실행한다. 닉네임으로 다시 로그인하면 같은 계정처럼 보이지만 **이전 후기는 사라진다.**
- 로그인은 새로고침/재실행해도 유지된다(마지막 닉네임으로 자동 재로그인). 로그아웃하면 지워진다.
- `http` (https 아님) 접속이라 사파리가 "보안 연결 아님"으로 표시할 수 있다. 개발용이므로 정상이다. 푸시 알림·위치 같은 보안 컨텍스트가 필요한 기능은 이 방식으로 못 쓴다.
- 사파리는 백그라운드 탭을 자주 닫는다. 그래도 닉네임으로 자동 재로그인된다.

### Tailscale로 밖에서도 접속
PC에 Tailscale이 설치돼 있다(`100.x.x.x` 주소). 아이폰에도 Tailscale 앱을 설치하고 같은 계정으로 로그인하면, LTE에서도 같은 방식으로 접속된다.
1. `tailscale ip -4` 로 PC의 Tailscale IP 확인 (예: `100.113.146.91`)
2. 위 3)의 빌드를 `build:web -- --host=100.113.146.91` 로 다시 하고, 아이폰에서 `http://100.113.146.91:5050` 접속
3. 방화벽 규칙의 `-Profile` 에 `Private` 대신 Tailscale 어댑터가 속한 프로필을 넣어야 할 수 있다.

---

## B. 실서버에 올리기 (플랜 3)
Firebase 프로젝트를 만들고 `flutterfire configure` 로 실제 설정을 넣은 뒤 `firebase deploy --only hosting,functions,firestore,storage` 하면 `https://<프로젝트>.web.app` 에서 아이폰 사파리로 접속된다. 이때 카카오·CLOVA 키가 필요하다. (`docs/deploy.md` 참고)

## C. 네이티브 iOS 앱 (TestFlight)
1. Apple Developer Program 가입(연 $99)
2. Mac이 있으면 `flutter build ipa` 후 Xcode로 업로드. Mac이 없으면 Codemagic·GitHub Actions(macOS runner) 같은 클라우드 빌드 사용
3. App Store Connect에서 TestFlight 내부 테스터로 본인 Apple ID 추가 → 아이폰의 TestFlight 앱에서 설치
4. 카카오·Apple 로그인, 카메라 권한(`Info.plist` 문구) 설정이 선행돼야 한다
