import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/time.dart';
import '../domain/models.dart';
import 'auth_service.dart';
import 'backend.dart';

final backendProvider = Provider<Backend>((ref) => FirebaseBackend());
final authServiceProvider = Provider<AuthService>((ref) => FirebaseAuthService());

/// 영수증 1장 선택. 모바일은 카메라, 웹은 파일 선택.
final imagePickerProvider = Provider<Future<XFile?> Function()>(
  (ref) => () => ImagePicker().pickImage(source: kIsWeb ? ImageSource.gallery : ImageSource.camera, maxWidth: 1600, imageQuality: 85),
);

/// 후기 사진 여러 장 선택.
final photosPickerProvider = Provider<Future<List<XFile>> Function()>(
  (ref) => () => ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 85),
);

final restaurantsProvider = StreamProvider.family<List<Restaurant>, (String, RestaurantSort)>(
  (ref, k) => ref.watch(backendProvider).watchRestaurants(k.$1, k.$2),
);
final restaurantProvider =
    StreamProvider.family<Restaurant?, String>((ref, id) => ref.watch(backendProvider).watchRestaurant(id));
final reviewsProvider = StreamProvider.family<List<Review>, (String, ReviewSort)>(
  (ref, k) => ref.watch(backendProvider).watchReviews(k.$1, k.$2),
);
final userProvider = StreamProvider.family<AppUser?, String>((ref, uid) => ref.watch(backendProvider).watchUser(uid));
final likedProvider = StreamProvider.family<bool, String>((ref, id) => ref.watch(backendProvider).watchLiked(id));
final crownProvider = FutureProvider.family<Crown?, String>(
  (ref, region) => ref.watch(backendProvider).getCrown(region, kstMonth(DateTime.now())),
);
final restaurantsByIdsProvider = FutureProvider.family<Map<String, Restaurant>, String>((ref, joined) async {
  if (joined.isEmpty) return {};
  return ref.watch(backendProvider).getRestaurants(joined.split(','));
});
