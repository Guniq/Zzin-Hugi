import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../core/env.dart';
import 'place_map_types.dart';

// web/kakao_map.js 가 window.zzinMap 으로 노출하는 함수들. 카카오 SDK 호출은 모두 그 파일 안에 있다.
@JS('zzinMap.load')
external JSPromise<JSAny?> _load(String appKey);

@JS('zzinMap.create')
external int _create(web.Element el, String optsJson, JSFunction onTap, JSFunction onMoved);

@JS('zzinMap.setMarkers')
external void _setMarkers(int id, String markersJson, String selectedId, bool fit);

@JS('zzinMap.moveTo')
external void _moveTo(int id, double lat, double lng);

@JS('zzinMap.locate')
external JSPromise<JSString?> _locate(int id);

@JS('zzinMap.destroy')
external void _destroy(int id);

const _viewType = 'zzin-kakao-map';
final _elements = <int, web.HTMLDivElement>{};
bool _registered = false;

void _ensureRegistered() {
  if (_registered) return;
  _registered = true;
  ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
    final el = web.document.createElement('div') as web.HTMLDivElement;
    el.style.width = '100%';
    el.style.height = '100%';
    _elements[viewId] = el;
    return el;
  });
}

Widget buildKakaoPlaceMap(
  BuildContext context, {
  required double lat,
  required double lng,
  required ValueChanged<PlaceMapHandle> onReady,
  required ValueChanged<String> onMarkerTap,
  required void Function(double lat, double lng) onUserMoved,
  required ValueChanged<String> onError,
}) =>
    _KakaoMapView(lat: lat, lng: lng, onReady: onReady, onMarkerTap: onMarkerTap, onUserMoved: onUserMoved, onError: onError);

class _KakaoMapView extends StatefulWidget {
  const _KakaoMapView({
    required this.lat,
    required this.lng,
    required this.onReady,
    required this.onMarkerTap,
    required this.onUserMoved,
    required this.onError,
  });
  final double lat;
  final double lng;
  final ValueChanged<PlaceMapHandle> onReady;
  final ValueChanged<String> onMarkerTap;
  final void Function(double lat, double lng) onUserMoved;
  final ValueChanged<String> onError;

  @override
  State<_KakaoMapView> createState() => _KakaoMapViewState();
}

class _KakaoMapViewState extends State<_KakaoMapView> {
  int? _viewId;
  int? _mapId;
  bool _sdkReady = false;

  @override
  void initState() {
    super.initState();
    _ensureRegistered();
    _loadSdk();
  }

  Future<void> _loadSdk() async {
    try {
      await _load(kakaoJsKey).toDart;
      if (!mounted) return;
      _sdkReady = true;
      _tryCreate();
    } catch (_) {
      if (mounted) widget.onError('sdk_load_failed');
    }
  }

  void _tryCreate() {
    if (_mapId != null || !_sdkReady || _viewId == null) return;
    final el = _elements[_viewId!];
    if (el == null) return;
    try {
      final id = _create(
        el,
        jsonEncode({'lat': widget.lat, 'lng': widget.lng, 'level': 4}),
        ((JSString markerId) => widget.onMarkerTap(markerId.toDart)).toJS,
        ((JSNumber la, JSNumber ln) => widget.onUserMoved(la.toDartDouble, ln.toDartDouble)).toJS,
      );
      _mapId = id;
      widget.onReady(_KakaoHandle(id));
    } catch (_) {
      widget.onError('map_create_failed');
    }
  }

  @override
  void dispose() {
    final id = _mapId;
    if (id != null) _destroy(id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(
        viewType: _viewType,
        onPlatformViewCreated: (id) {
          _viewId = id;
          _tryCreate();
        },
      );
}

class _KakaoHandle implements PlaceMapHandle {
  _KakaoHandle(this.id);
  final int id;

  @override
  Future<void> setMarkers(List<MapMarkerData> markers, {String? selectedId, bool fit = false}) async {
    _setMarkers(id, jsonEncode([for (final m in markers) m.toJson()]), selectedId ?? '', fit);
  }

  @override
  Future<void> moveTo(double lat, double lng) async => _moveTo(id, lat, lng);

  @override
  Future<MapLatLng?> locate() async {
    final raw = await _locate(id).toDart;
    if (raw == null) return null;
    final m = jsonDecode(raw.toDart) as Map<String, dynamic>;
    return MapLatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
  }
}
