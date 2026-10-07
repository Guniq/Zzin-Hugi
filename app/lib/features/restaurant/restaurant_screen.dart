import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/score.dart';
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
      appBar: AppBar(title: Text(r?.name ?? '식당')),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: Theme.of(context).textTheme.headlineSmall),
                      Text(r.address),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text('찐 ${scoreText(r.realScore)}')),
                          if (r.eventScore != null) Chip(label: Text('이벤트 ${scoreText(r.eventScore)}')),
                          if (r.bubble != null) Chip(label: Text('거품 ${bubbleText(r.bubble)}')),
                          Chip(label: Text('후기 ${r.reviewCount}')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => context.push('/write', extra: r.toPlace()),
                        icon: const Icon(Icons.edit),
                        label: const Text('이 식당 후기 쓰기'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('따봉순'),
                        selected: _sort == ReviewSort.likes,
                        onSelected: (_) => setState(() => _sort = ReviewSort.likes),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('최신순'),
                        selected: _sort == ReviewSort.recent,
                        onSelected: (_) => setState(() => _sort = ReviewSort.recent),
                      ),
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
