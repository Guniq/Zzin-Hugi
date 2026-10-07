class BetaRegion {
  const BetaRegion(this.id, this.name, this.lat, this.lng);
  final String id;
  final String name;

  /// 지도·검색의 시작 위치(화곡역 인근). 서버 DEFAULT_NEAR 와 같은 기준점.
  final double lat;
  final double lng;
}

// config/regions 는 클라이언트가 읽을 수 없어서 앱에 고정. 지역을 늘릴 땐 둘 다 수정.
const List<BetaRegion> betaRegions = [BetaRegion('hwagok', '화곡', 37.5412, 126.8402)];
