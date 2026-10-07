/// 카카오에서 돌아온 주소의 파라미터.
class KakaoRedirectParams {
  const KakaoRedirectParams({this.code, this.state, this.error});
  final String? code;
  final String? state;

  /// 사용자가 동의 화면에서 취소했거나 카카오가 오류를 돌려준 경우(`error` 값)
  final String? error;
}

// 웹이 아닌 환경에서는 카카오 웹 로그인을 쓰지 않는다.
String kakaoRedirectUri() => '';
void kakaoRedirectTo(String url) => throw UnsupportedError('카카오 웹 로그인은 웹에서만 쓸 수 있어요');
void kakaoSaveState(String state) {}
String? kakaoTakeState() => null;
KakaoRedirectParams? kakaoReadParams() => null;
void kakaoCleanUrl() {}
