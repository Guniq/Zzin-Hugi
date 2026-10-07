import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zzinhugi/data/auth_service.dart';
import 'package:zzinhugi/data/backend.dart';
import 'package:zzinhugi/data/providers.dart';
import 'package:zzinhugi/domain/models.dart';

class FakeAuth implements AuthService {
  FakeAuth([this.uid = 'me']);
  String? uid;
  String? lastNickname;
  bool signedOut = false;

  @override
  String? get currentUid => uid;
  @override
  Stream<String?> get uidChanges => Stream.value(uid);
  @override
  Future<void> signInDebug(String nickname) async {
    lastNickname = nickname;
    uid = 'me';
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    uid = null;
  }
}

class FakeBackend extends Fake implements Backend {
  List<Restaurant> restaurants = [];
  List<Review> reviews = [];
  Map<String, AppUser> users = {};
  Map<String, bool> liked = {};
  List<PlaceResult> places = [];
  Crown? crown;
  SubmitInput? lastSubmit;
  Object? submitError;
  Object? searchError;
  final likeCalls = <(String, bool)>[];
  final reports = <(String, String)>[];
  final uploads = <String>[];
  final searched = <String>[];
  final searchCalls = <(String, double?, double?)>[];

  @override
  Stream<List<Restaurant>> watchRestaurants(String region, RestaurantSort sort) => Stream.value(restaurants);
  @override
  Stream<Restaurant?> watchRestaurant(String id) => Stream.value(restaurants.where((r) => r.id == id).firstOrNull);
  @override
  Stream<List<Review>> watchReviews(String restaurantId, ReviewSort sort) => Stream.value(reviews);
  @override
  Stream<AppUser?> watchUser(String uid) => Stream.value(users[uid]);
  @override
  Future<Map<String, Restaurant>> getRestaurants(List<String> ids) async => {
        for (final r in restaurants)
          if (ids.contains(r.id)) r.id: r
      };
  @override
  Future<Crown?> getCrown(String region, String month) async => crown;
  @override
  Future<List<PlaceResult>> searchPlaces(String query, {double? lat, double? lng}) async {
    searched.add(query);
    searchCalls.add((query, lat, lng));
    if (searchError != null) throw searchError!;
    return places;
  }

  @override
  Future<String> uploadImage(String folder, Uint8List bytes, String contentType) async {
    final path = '$folder/me/${uploads.length}.jpg';
    uploads.add(path);
    return path;
  }

  @override
  Future<String> submitReview(SubmitInput input) async {
    if (submitError != null) throw submitError!;
    lastSubmit = input;
    return 'me_${input.placeId}';
  }

  @override
  Stream<bool> watchLiked(String reviewId) => Stream.value(liked[reviewId] ?? false);
  @override
  Future<void> setLike(String reviewId, bool on) async => likeCalls.add((reviewId, on));
  @override
  Future<void> report(String reviewId, String reason) async => reports.add((reviewId, reason));
  @override
  Future<String> downloadUrl(String path) async => 'http://localhost/$path';
}

/// 화면 하나를 `/` 로 띄우고, 이동 대상 경로는 글자만 보이는 스텁으로 대체한다.
Widget harness({
  required Widget child,
  required FakeBackend backend,
  FakeAuth? auth,
  List<Override> overrides = const [],
}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => child),
    GoRoute(path: '/login', builder: (_, _) => const Text('login-page')),
    GoRoute(path: '/r/:id', builder: (_, s) => Text('detail:${s.pathParameters['id']}')),
    GoRoute(path: '/write', builder: (_, s) => Text('write:${(s.extra as PlaceResult?)?.placeId ?? ''}')),
    GoRoute(path: '/u/:uid', builder: (_, s) => Text('profile:${s.pathParameters['uid']}')),
  ]);
  return ProviderScope(
    overrides: [
      backendProvider.overrideWithValue(backend),
      authServiceProvider.overrideWithValue(auth ?? FakeAuth()),
      ...overrides,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

AppUser appUser(String uid, {int verified = 1, Map<String, List<String>> ranking = const {}}) => AppUser.fromMap(uid, {
      'nickname': '닉-$uid',
      'title': '찐린이',
      'likesReceived': 0,
      'verifiedReviewCount': verified,
      'ranking': ranking,
    });
