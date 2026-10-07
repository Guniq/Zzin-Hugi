import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/score.dart';
import '../../ui/gauge.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'review_card.dart';

class RestaurantScreen extends ConsumerStatefulWidget {
  const RestaurantScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen> {
  ReviewSort _sort = ReviewSort.likes;

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(restaurantProvider(widget.id)).value;
    final reviews = ref.watch(reviewsProvider((widget.id, _sort)));
    return Scaffold(
      appBar: AppBar(
        actions: [IconButton(tooltip: '홈', icon: const Icon(Icons.home_outlined), onPressed: () => context.go('/'))],
      ),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 2),
                      Text(r.address, style: const TextStyle(fontSize: 14, color: AppColors.sub)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _ScoreCard(r: r),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: FilledButton(
                    onPressed: () => context.push('/write', extra: r.toPlace()),
                    child: const Text('이 식당 후기 쓰기'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                  child: Row(
                    children: [
                      pill('따봉순', selected: _sort == ReviewSort.likes, onSelected: () => setState(() => _sort = ReviewSort.likes)),
                      const SizedBox(width: 8),
                      pill('최신순', selected: _sort == ReviewSort.recent, onSelected: () => setState(() => _sort = ReviewSort.recent)),
                    ],
                  ),
                ),
                ...reviews.when(
                  loading: () => [const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))],
                  error: (e, _) => [Padding(padding: const EdgeInsets.all(24), child: Text('불러오지 못했어요: $e'))],
                  data: (list) => list.isEmpty
                      ? [const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('아직 후기가 없어요')))]
                      : [for (final v in list) ReviewCard(review: v)],
                ),
              ],
            ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.r});
  final Restaurant r;

  @override
  Widget build(BuildContext context) {
    final hasScore = r.realScore != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('찐점수', style: TextStyle(fontSize: 13, color: AppColors.sub)),
                      Text(
                        scoreText(r.realScore),
                        style: TextStyle(
                          fontSize: hasScore ? 56 : 22,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          letterSpacing: -1,
                          color: hasScore ? AppColors.ink : AppColors.sub,
                        ),
                      ),
                    ],
                  ),
                ),
                if (r.bubble != null) BubbleBadge('거품 ${bubbleText(r.bubble)}', large: true),
              ],
            ),
            const SizedBox(height: 22),
            BubbleGauge(real: r.realScore, event: r.eventScore),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('● 찐점수 (인증 후기 평균)', style: TextStyle(fontSize: 12, color: AppColors.sub)),
                Text('○ 이벤트 별점', style: TextStyle(fontSize: 12, color: AppColors.sub)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat('이벤트 점수', scoreText(r.eventScore).replaceAll('데이터 부족', '-')),
                const SizedBox(width: 8),
                _Stat('전체 후기', '${r.reviewCount}'),
                const SizedBox(width: 8),
                _Stat('이벤트 후기', '${r.eventReviewCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: AppColors.ground, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}
