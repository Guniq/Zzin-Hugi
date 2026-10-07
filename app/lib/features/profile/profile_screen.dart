import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/score.dart';
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
    final allIds = [for (final t in Tier.values) ...?user.ranking[t]];
    final names = ref.watch(restaurantsByIdsProvider(allIds.join(','))).value ?? const {};
    return DefaultTabController(
      length: Tier.values.length,
      child: Column(
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TabBar(tabs: [for (final t in Tier.values) Tab(text: t.label)]),
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final t in Tier.values) _TierList(tier: t, ids: user.ranking[t] ?? const [], names: names),
              ],
            ),
          ),
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
      ),
    );
  }
}

class _TierList extends StatelessWidget {
  const _TierList({required this.tier, required this.ids, required this.names});
  final Tier tier;
  final List<String> ids;
  final Map<String, Restaurant> names;

  @override
  Widget build(BuildContext context) {
    if (ids.isEmpty) return const Center(child: Text('아직 없어요'));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      itemCount: ids.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/r/${ids[i]}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(width: 32, child: Text('${i + 1}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(names[ids[i]]?.name ?? ids[i], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        if (names[ids[i]] != null)
                          Text(names[ids[i]]!.address, style: const TextStyle(fontSize: 13, color: AppColors.sub)),
                      ],
                    ),
                  ),
                  Text(scoreText(personalScore(tier, i, ids.length)), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
