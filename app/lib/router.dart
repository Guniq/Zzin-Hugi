import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/providers.dart';
import 'domain/models.dart';
import 'features/home/home_screen.dart';
import 'features/login/login_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/restaurant/restaurant_screen.dart';
import 'features/write/write_review_screen.dart';

class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> s) {
    _sub = s.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authServiceProvider);
  final refresh = _StreamListenable(auth.uidChanges);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = auth.currentUid != null;
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn) return atLogin ? null : '/login';
      if (atLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/r/:id', builder: (_, s) => RestaurantScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/write', builder: (_, s) => WriteReviewScreen(initialPlace: s.extra as PlaceResult?)),
      GoRoute(path: '/u/:uid', builder: (_, s) => ProfileScreen(uid: s.pathParameters['uid']!)),
    ],
  );
});
