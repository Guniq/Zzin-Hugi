import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/score.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider(uid));
    final mine = ref.read(authServiceProvider).currentUid == uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(mine ? '내 프로필' : '프로필'),
        actions: [
          if (mine)
            TextButton(
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
              },
              child: const Text('로그아웃'),
            ),
        ],
      ),
      body: user.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오지 못했어요: $e')),
        data: (u) => u == null ? const Center(child: Text('프로필을 찾을 수 없어요')) : _Body(user: u),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allIds = [for (final t in Tier.values) ...?user.ranking[t]];
    final names = ref.watch(restaurantsByIdsProvider(allIds.join(','))).value ?? const {};
    return DefaultTabController(
      length: Tier.values.length,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(user.nickname, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Chip(label: Text(user.title)),
                Text('받은 따봉 ${user.likesReceived}'),
              ],
            ),
          ),
          TabBar(tabs: [for (final t in Tier.values) Tab(text: t.label)]),
          Expanded(
            child: TabBarView(
              children: [
                for (final t in Tier.values) _TierList(tier: t, ids: user.ranking[t] ?? const [], names: names),
              ],
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
      itemCount: ids.length,
      itemBuilder: (_, i) => ListTile(
        leading: Text('${i + 1}', style: Theme.of(context).textTheme.titleMedium),
        title: Text(names[ids[i]]?.name ?? ids[i]),
        trailing: Text(scoreText(personalScore(tier, i, ids.length))),
        onTap: () => context.push('/r/${ids[i]}'),
      ),
    );
  }
}
