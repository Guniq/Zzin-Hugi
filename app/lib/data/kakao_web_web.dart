import 'package:web/web.dart' as web;

/// 카카오에서 돌아온 주소의 파라미터.
class KakaoRedirectParams {
  const KakaoRedirectParams({this.code, this.state, this.error});
  final String? code;
  final String? state;

  /// 사용자가 동의 화면에서 취소했거나 카카오가 오류를 돌려준 경우(`error` 값)
  final String? error;
}

const _stateKey = 'zzin_kakao_state';

/// 카카오 콘솔의 Redirect URI 에 등록해야 하는 주소(현재 접속 주소의 루트).
String kakaoRedirectUri() => '${web.window.location.origin}/';

void kakaoRedirectTo(String url) => web.window.location.assign(url);

/// 로그인 시작 때 만든 임의 값을 저장해 두었다가, 돌아왔을 때 같은 값인지 확인한다(CSRF 방지).
void kakaoSaveState(String state) => web.window.sessionStorage.setItem(_stateKey, state);

String? kakaoTakeState() {
  final v = web.window.sessionStorage.getItem(_stateKey);
  web.window.sessionStorage.removeItem(_stateKey);
  return v;
}

/// 현재 주소가 카카오에서 돌아온 주소(`?code=…` 또는 `?error=…`)면 파라미터, 아니면 null.
KakaoRedirectParams? kakaoReadParams() {
  final q = Uri.base.queryParameters;
  final code = q['code'];
  final error = q['error'];
  if (code == null && error == null) return null;
  return KakaoRedirectParams(code: code, state: q['state'], error: error);
}

/// 주소창에서 `?code=…&state=…` 를 지운다(새로고침해도 같은 코드로 다시 로그인하지 않게).
void kakaoCleanUrl() {
  final l = web.window.location;
  web.window.history.replaceState(null, '', '${l.origin}${l.pathname}${l.hash}');
}
