import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/score.dart';

class ReviewCard extends ConsumerWidget {
  const ReviewCard({super.key, required this.review});
  final Review review;

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _toggleLike(BuildContext context, WidgetRef ref, bool liked, AppUser? me) async {
    if (!liked && (me?.verifiedReviewCount ?? 0) < 1) {
      _snack(context, '영수증 인증 후기를 1개 이상 쓰면 따봉을 줄 수 있어요');
      return;
    }
    try {
      await ref.read(backendProvider).setLike(review.id, !liked);
    } catch (_) {
      if (context.mounted) _snack(context, '따봉을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 후기를 신고할까요?'),
        content: TextField(controller: c, maxLength: 200, decoration: const InputDecoration(labelText: '사유')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('신고하기')),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await ref.read(backendProvider).report(review.id, reason);
    if (context.mounted) _snack(context, '신고가 접수됐어요');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.read(authServiceProvider).currentUid ?? '';
    final me = ref.watch(userProvider(myUid)).value;
    final author = ref.watch(userProvider(review.uid)).value;
    final liked = ref.watch(likedProvider(review.id)).value ?? false;
    final mine = review.uid == myUid;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => context.push('/u/${review.uid}'),
                  child: Text(author?.nickname ?? '…', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                if (author != null) Chip(label: Text(author.title), visualDensity: VisualDensity.compact),
                const Spacer(),
                Text(review.visitDate, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                Text('${review.tier.label} ${scoreText(review.personalScore)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                if (review.eventJoined)
                  Text('🎁 이벤트 참여 · 별점 ${review.eventStars}', style: TextStyle(color: Colors.orange.shade800)),
              ],
            ),
            const SizedBox(height: 6),
            Text(review.text),
            if (review.photos.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [for (final p in review.photos) _Photo(path: p)],
                ),
              ),
            ],
            Row(
              children: [
                IconButton(
                  tooltip: '따봉',
                  icon: Icon(liked ? Icons.thumb_up : Icons.thumb_up_outlined),
                  onPressed: mine ? null : () => _toggleLike(context, ref, liked, me),
                ),
                Text('${review.likeCount}'),
                const Spacer(),
                IconButton(tooltip: '신고', icon: const Icon(Icons.flag_outlined), onPressed: () => _report(context, ref)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Photo extends ConsumerWidget {
  const _Photo({required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FutureBuilder<String>(
        future: ref.read(backendProvider).downloadUrl(path),
        builder: (_, snap) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 96,
            height: 96,
            child: snap.hasData ? Image.network(snap.data!, fit: BoxFit.cover) : const ColoredBox(color: Colors.black12),
          ),
        ),
      ),
    );
  }
}
