import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/regions.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import 'restaurant_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final BetaRegion _region = betaRegions.first;
  RestaurantSort _sort = RestaurantSort.real;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(restaurantsProvider((_region.id, _sort)));
    return Scaffold(
      appBar: AppBar(
        title: Text('찐후기 · ${_region.name}'),
        actions: [
          IconButton(
            tooltip: '내 프로필',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/u/${ref.read(authServiceProvider).currentUid}'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/write'),
        icon: const Icon(Icons.edit),
        label: const Text('후기 쓰기'),
      ),
      body: Column(
        children: [
          _CrownBanner(regionId: _region.id),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('찐점수순'),
                  selected: _sort == RestaurantSort.real,
                  onSelected: (_) => setState(() => _sort = RestaurantSort.real),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('거품 큰 순'),
                  selected: _sort == RestaurantSort.bubble,
                  onSelected: (_) => setState(() => _sort = RestaurantSort.bubble),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('불러오지 못했어요: $e')),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('아직 후기가 없어요. 첫 찐후기를 남겨 보세요!'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: items.length,
                      itemBuilder: (_, i) => RestaurantCard(restaurant: items[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrownBanner extends ConsumerWidget {
  const _CrownBanner({required this.regionId});
  final String regionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crown = ref.watch(crownProvider(regionId)).value;
    if (crown == null) return const SizedBox.shrink();
    final nick = ref.watch(userProvider(crown.uid)).value?.nickname ?? '';
    return Material(
      color: Colors.amber.shade100,
      child: InkWell(
        onTap: () => context.push('/u/${crown.uid}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('👑 '),
              Expanded(child: Text('이번 달 찐후기 대마왕 · $nick (따봉 ${crown.likes})')),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
