import 'package:flutter/widgets.dart';

class MapLatLng {
  const MapLatLng(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// 지도에 찍을 핀 하나. [blocked] 는 베타 지역 밖(후기를 쓸 수 없는) 가게.
class MapMarkerData {
  const MapMarkerData({required this.id, required this.lat, required this.lng, required this.name, required this.blocked, this.badge = ''});
  final String id;
  final double lat;
  final double lng;
  final String name;
  final bool blocked;

  /// 핀 알약 안에 보여 줄 짧은 글자(찐점수 "7.8" 또는 "후기 2"). 없으면 빈 문자열.
  final String badge;

  Map<String, Object> toJson() => {'id': id, 'lat': lat, 'lng': lng, 'name': name, 'blocked': blocked, 'badge': badge};
}

/// 지도 위젯이 준비되면 넘겨주는 조작 핸들.
abstract class PlaceMapHandle {
  /// 핀을 모두 다시 그린다. [fit] 이면 핀이 다 보이게 지도를 맞춘다.
  Future<void> setMarkers(List<MapMarkerData> markers, {String? selectedId, bool fit = false});
  Future<void> moveTo(double lat, double lng);

  /// 현재 위치. 못 가져오면(https 아님, 권한 거부 등) null.
  Future<MapLatLng?> locate();
}

/// 지도 위젯을 만드는 함수. 웹은 카카오맵, 테스트는 가짜 지도로 바꿔 끼운다.
typedef PlaceMapBuilder = Widget Function(
  BuildContext context, {
  required double lat,
  required double lng,
  required ValueChanged<PlaceMapHandle> onReady,
  required ValueChanged<String> onMarkerTap,
  required void Function(double lat, double lng) onUserMoved,
  required ValueChanged<String> onError,
});
