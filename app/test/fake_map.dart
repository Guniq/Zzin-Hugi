import 'package:flutter/material.dart';
import 'package:zzinhugi/features/write/map/place_map.dart';

/// 테스트용 가짜 지도. 실제 카카오맵 대신 이 객체로 핀 탭·지도 이동을 흉내 낸다.
class FakeMapControls {
  void Function(String id)? tapMarker;
  void Function(double lat, double lng)? userMoved;
  void Function(String message)? error;
  final markerCalls = <({List<MapMarkerData> markers, String? selectedId, bool fit})>[];
  final moves = <(double, double)>[];
  MapLatLng? locateResult;
  int builds = 0;
}

PlaceMapBuilder fakeMapBuilder(FakeMapControls c) => (
      BuildContext context, {
      required double lat,
      required double lng,
      required ValueChanged<PlaceMapHandle> onReady,
      required ValueChanged<String> onMarkerTap,
      required void Function(double lat, double lng) onUserMoved,
      required ValueChanged<String> onError,
    }) {
      c.builds++;
      c.tapMarker = onMarkerTap;
      c.userMoved = onUserMoved;
      c.error = onError;
      WidgetsBinding.instance.addPostFrameCallback((_) => onReady(_FakeHandle(c)));
      return const ColoredBox(color: Color(0xFFEEF0F2), child: SizedBox.expand());
    };

class _FakeHandle implements PlaceMapHandle {
  _FakeHandle(this.c);
  final FakeMapControls c;

  @override
  Future<void> setMarkers(List<MapMarkerData> markers, {String? selectedId, bool fit = false}) async {
    c.markerCalls.add((markers: markers, selectedId: selectedId, fit: fit));
  }

  @override
  Future<void> moveTo(double lat, double lng) async => c.moves.add((lat, lng));

  @override
  Future<MapLatLng?> locate() async => c.locateResult;
}
