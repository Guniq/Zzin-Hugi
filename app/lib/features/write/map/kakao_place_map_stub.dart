import 'package:flutter/material.dart';

import 'place_map_types.dart';

/// 웹이 아닌 환경(모바일 앱 등)의 자리표시. 네이티브 지도는 플랜 3에서 붙인다.
Widget buildKakaoPlaceMap(
  BuildContext context, {
  required double lat,
  required double lng,
  required ValueChanged<PlaceMapHandle> onReady,
  required ValueChanged<String> onMarkerTap,
  required void Function(double lat, double lng) onUserMoved,
  required ValueChanged<String> onError,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) => onError('unsupported_platform'));
  return const ColoredBox(color: Color(0xFFEEF0F2), child: SizedBox.expand());
}
