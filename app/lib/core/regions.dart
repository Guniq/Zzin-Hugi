class BetaRegion {
  const BetaRegion(this.id, this.name);
  final String id;
  final String name;
}

// config/regions 는 클라이언트가 읽을 수 없어서 앱에 고정. 지역을 늘릴 땐 둘 다 수정.
const List<BetaRegion> betaRegions = [BetaRegion('hwagok', '화곡')];
