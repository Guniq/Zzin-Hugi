import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/regions.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/write'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit),
        label: const Text('후기 쓰기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('찐후기', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  const SizedBox(width: 8),
                  Text(_region.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.sub)),
                  const Spacer(),
                  IconButton.outlined(
                    tooltip: '내 프로필',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      backgroundColor: AppColors.card,
                      side: const BorderSide(color: AppColors.line),
                    ),
                    icon: const Icon(Icons.person_outline),
                    onPressed: () => context.push('/u/${ref.read(authServiceProvider).currentUid}'),
                  ),
                ],
              ),
            ),
            _CrownBanner(regionId: _region.id),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  pill('찐점수순', selected: _sort == RestaurantSort.real, onSelected: () => setState(() => _sort = RestaurantSort.real)),
                  const SizedBox(width: 8),
                  pill('거품 큰 순', selected: _sort == RestaurantSort.bubble, onSelected: () => setState(() => _sort = RestaurantSort.bubble)),
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
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: items.length,
                        itemBuilder: (_, i) => RestaurantCard(restaurant: items[i]),
                      ),
              ),
            ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/u/${crown.uid}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_outlined, color: AppColors.gold, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('이번 달 찐후기 대마왕', style: TextStyle(fontSize: 12, color: Color(0xFFC9CDD2))),
                      Text('$nick · 따봉 ${crown.likes}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFC9CDD2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
