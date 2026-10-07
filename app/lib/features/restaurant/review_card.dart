import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/score.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialAvatar(author?.nickname ?? ''),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => context.push('/u/${review.uid}'),
                        child: Text(author?.nickname ?? '…', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      Text(
                        '${author?.title ?? ''} · ${review.visitDate}',
                        style: const TextStyle(fontSize: 12, color: AppColors.sub),
                      ),
                    ],
                  ),
                ),
                Text(scoreText(review.personalScore), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Tag(review.tier.label, fill: AppColors.ink, color: Colors.white),
                if (review.eventJoined)
                  _Tag('이벤트 참여 · 별점 ${review.eventStars}', fill: AppColors.accentSoft, color: AppColors.accentText),
              ],
            ),
            const SizedBox(height: 10),
            Text(review.text, style: const TextStyle(fontSize: 15, height: 1.55)),
            if (review.photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [for (final p in review.photos) _Photo(path: p)],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton.icon(
                  onPressed: mine ? null : () => _toggleLike(context, ref, liked, me),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: AppColors.ink),
                  icon: Icon(liked ? Icons.thumb_up : Icons.thumb_up_outlined, size: 20),
                  label: Text('${review.likeCount}'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '신고',
                  color: AppColors.sub,
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () => _report(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.fill, required this.color});
  final String text;
  final Color fill;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      );
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
          borderRadius: BorderRadius.circular(10),
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
