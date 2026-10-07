import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/env.dart';
import 'kakao_place_map.dart';
import 'place_map_types.dart';

export 'place_map_types.dart';

/// 실제 지도 구현. 웹은 카카오맵 JS SDK, 그 외는 안내 문구.
final placeMapBuilderProvider = Provider<PlaceMapBuilder>((ref) => buildKakaoPlaceMap);

/// 지도 검색을 쓸 수 있는지: 웹이고 카카오 JavaScript 키가 들어 있을 때만.
final mapEnabledProvider = Provider<bool>((ref) => kIsWeb && kakaoJsKey.isNotEmpty);
