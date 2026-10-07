import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider(uid));
    final mine = ref.read(authServiceProvider).currentUid == uid;
    return Scaffold(
      appBar: AppBar(),
      body: user.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오지 못했어요: $e')),
        data: (u) => u == null ? const Center(child: Text('프로필을 찾을 수 없어요')) : _Body(user: u, mine: mine),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.user, required this.mine});
  final AppUser user;
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(userReviewsProvider(user.uid)).value ?? const <Review>[];
    final names = ref.watch(restaurantsByIdsProvider({for (final r in reviews) r.restaurantId}.join(','))).value ?? const {};
    return Column(
        children: [
          Column(
            children: [
              InitialAvatar(user.nickname, size: 88),
              const SizedBox(height: 12),
              Text(user.nickname, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(14)),
                    child: Text(user.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gold)),
                  ),
                  const SizedBox(width: 8),
                  Text('받은 따봉 ${user.likesReceived}', style: const TextStyle(fontSize: 14, color: AppColors.sub)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(alignment: Alignment.centerLeft, child: Text('내가 쓴 후기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ),
          Expanded(child: _ReviewList(reviews: reviews, names: names)),
          if (mine)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async => ref.read(authServiceProvider).signOut(),
                  child: const Text('로그아웃'),
                ),
              ),
            ),
        ],
    );
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({required this.reviews, required this.names});
  final List<Review> reviews;
  final Map<String, Restaurant> names;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const Center(child: Text('아직 쓴 후기가 없어요'));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      itemCount: reviews.length,
      itemBuilder: (_, i) {
        final r = reviews[i];
        final rest = names[r.restaurantId];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/r/${r.restaurantId}'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rest?.name ?? r.restaurantId, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          if (r.eventJoined)
                            Text('이벤트 ★${r.eventStars} → 실제 ★${r.stars}', style: const TextStyle(fontSize: 13, color: AppColors.sub)),
                        ],
                      ),
                    ),
                    Text('★ ${r.stars}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
