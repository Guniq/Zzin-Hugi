import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class ReviewCard extends ConsumerStatefulWidget {
  const ReviewCard({super.key, required this.review});
  final Review review;

  @override
  ConsumerState<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<ReviewCard> {
  Review get review => widget.review;

  /// 따봉을 누른 직후 서버 집계(likeCount)가 오기 전까지 화면에 먼저 반영하는 값.
  bool? _optLiked;
  int _optBase = 0;

  @override
  void didUpdateWidget(ReviewCard old) {
    super.didUpdateWidget(old);
    if (old.review.likeCount != widget.review.likeCount) _optLiked = null; // 서버 값이 도착함
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _toggleLike(BuildContext context, bool liked, AppUser? me) async {
    if (!liked && (me?.verifiedReviewCount ?? 0) < 1) {
      _snack(context, '영수증 인증 후기를 1개 이상 쓰면 따봉을 줄 수 있어요');
      return;
    }
    setState(() {
      _optLiked = !liked;
      _optBase = review.likeCount;
    });
    try {
      await ref.read(backendProvider).setLike(review.id, !liked);
    } catch (_) {
      if (mounted) setState(() => _optLiked = null);
      if (context.mounted) _snack(context, '따봉을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  Future<void> _report(BuildContext context) async {
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
  Widget build(BuildContext context) {
    final myUid = ref.read(authServiceProvider).currentUid ?? '';
    final me = ref.watch(userProvider(myUid)).value;
    final author = ref.watch(userProvider(review.uid)).value;
    final streamLiked = ref.watch(likedProvider(review.id)).value ?? false;
    final liked = _optLiked ?? streamLiked;
    final likeCount = _optLiked == null ? review.likeCount : (_optBase + (_optLiked! ? 1 : -1)).clamp(0, 1 << 30);
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
                Text('★ ${review.stars}', key: const Key('review-stars'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (review.eventJoined)
                  _Tag('이벤트 ★${review.eventStars} → 실제 ★${review.stars}', fill: AppColors.accentSoft, color: AppColors.accentText),
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
                  children: [for (var i = 0; i < review.photos.length; i++) _Photo(paths: review.photos, index: i)],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton.icon(
                  onPressed: mine ? null : () => _toggleLike(context, liked, me),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: AppColors.ink),
                  icon: Icon(liked ? Icons.thumb_up : Icons.thumb_up_outlined, size: 20),
                  label: Text('$likeCount', semanticsLabel: '따봉 $likeCount'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '신고',
                  color: AppColors.sub,
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () => _report(context),
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
  const _Photo({required this.paths, required this.index});
  final List<String> paths;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FutureBuilder<String>(
        future: ref.read(backendProvider).downloadUrl(paths[index]),
        builder: (_, snap) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 96,
            height: 96,
            child: snap.hasData
                ? InkWell(
                    onTap: () => showDialog<void>(context: context, builder: (_) => _PhotoViewer(paths: paths, start: index)),
                    child: Image.network(snap.data!, fit: BoxFit.cover),
                  )
                : const ColoredBox(color: Colors.black12),
          ),
        ),
      ),
    );
  }
}

/// 사진 크게 보기: 좌우로 넘기고, 두 손가락/휠로 확대한다.
class _PhotoViewer extends ConsumerStatefulWidget {
  const _PhotoViewer({required this.paths, required this.start});
  final List<String> paths;
  final int start;

  @override
  ConsumerState<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<_PhotoViewer> {
  late final _ctrl = PageController(initialPage: widget.start);
  late int _page = widget.start;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _go(int d) => _ctrl.animateToPage(_page + d, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final n = widget.paths.length;
    return Dialog.fullscreen(
      backgroundColor: Colors.black87,
      child: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: n,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => FutureBuilder<String>(
              future: ref.read(backendProvider).downloadUrl(widget.paths[i]),
              builder: (_, snap) => snap.hasData
                  ? GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: InteractiveViewer(maxScale: 5, child: Center(child: Image.network(snap.data!, fit: BoxFit.contain))),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(tooltip: '닫기', color: Colors.white, icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ),
          ),
          if (n > 1) ...[
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Text('${_page + 1} / $n', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            if (_page > 0)
              Align(alignment: Alignment.centerLeft, child: IconButton(tooltip: '이전 사진', color: Colors.white, iconSize: 36, icon: const Icon(Icons.chevron_left), onPressed: () => _go(-1))),
            if (_page < n - 1)
              Align(alignment: Alignment.centerRight, child: IconButton(tooltip: '다음 사진', color: Colors.white, iconSize: 36, icon: const Icon(Icons.chevron_right), onPressed: () => _go(1))),
          ],
        ],
      ),
    );
  }
}
