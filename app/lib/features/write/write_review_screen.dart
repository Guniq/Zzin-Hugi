import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/providers.dart';
import '../../domain/errors.dart';
import '../../domain/models.dart';
import '../../domain/ranking_session.dart';
import '../../domain/score.dart';

class WriteReviewScreen extends ConsumerStatefulWidget {
  const WriteReviewScreen({super.key, this.initialPlace});
  final PlaceResult? initialPlace;

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  static const _lastStep = 5;
  static const _titles = ['식당 찾기', '영수증 인증', '어땠나요?', '순위 정하기', '리뷰 이벤트', '한줄평'];

  int _step = 0;
  PlaceResult? _place;
  List<PlaceResult> _results = [];
  final _query = TextEditingController();
  final _text = TextEditingController();
  XFile? _receipt;
  Tier? _tier;
  Map<String, Restaurant> _names = {};
  RankingSession? _session;
  bool _eventJoined = false;
  int _stars = 5;
  List<XFile> _photos = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _place = widget.initialPlace;
    _step = _place == null ? 0 : 1;
  }

  @override
  void dispose() {
    _query.dispose();
    _text.dispose();
    super.dispose();
  }

  bool get _canNext => switch (_step) {
        0 => _place != null && _place!.region != null,
        1 => _receipt != null,
        2 => _tier != null,
        3 => _session?.done ?? false,
        4 => true,
        _ => _text.text.trim().length >= 10 && _text.text.trim().length <= 300,
      };

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() => _error = null);
    try {
      final r = await ref.read(backendProvider).searchPlaces(q);
      if (mounted) setState(() => _results = r);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = reviewErrorText(e.message));
    } catch (_) {
      if (mounted) setState(() => _error = reviewErrorText(null));
    }
  }

  Future<void> _prepareCompare() async {
    final backend = ref.read(backendProvider);
    final uid = ref.read(authServiceProvider).currentUid!;
    final user = await backend.watchUser(uid).first;
    final ids = [
      for (final id in user?.ranking[_tier!] ?? const <String>[])
        if (id != _place!.placeId) id
    ];
    _names = ids.isEmpty ? <String, Restaurant>{} : await backend.getRestaurants(ids);
    _session = RankingSession(ids);
  }

  Future<void> _next() async {
    if (_step == 2) await _prepareCompare();
    if (mounted) setState(() => _step++);
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final backend = ref.read(backendProvider);
    try {
      final receiptPath = await backend.uploadImage('receipts', await _receipt!.readAsBytes(), _receipt!.mimeType ?? 'image/jpeg');
      final photoPaths = <String>[];
      for (final p in _photos) {
        photoPaths.add(await backend.uploadImage('photos', await p.readAsBytes(), p.mimeType ?? 'image/jpeg'));
      }
      await backend.submitReview(SubmitInput(
        placeId: _place!.placeId,
        receiptPath: receiptPath,
        tier: _tier!,
        rankIndex: _session!.index,
        eventJoined: _eventJoined,
        eventStars: _eventJoined ? _stars : null,
        text: _text.text.trim(),
        photos: photoPaths,
      ));
      if (!mounted) return;
      context.go('/r/${_place!.placeId}');
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = reviewErrorText(e.message));
    } catch (_) {
      if (mounted) setState(() => _error = reviewErrorText(null));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.initialPlace == null ? 0 : 1;
    return Scaffold(
      appBar: AppBar(title: Text('후기 쓰기 · ${_titles[_step]}')),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_step + 1) / (_lastStep + 1)),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _page())),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_step > first)
                  OutlinedButton(
                    onPressed: _busy ? null : () => setState(() => _step--),
                    child: const Text('이전'),
                  ),
                const Spacer(),
                if (_step < _lastStep)
                  FilledButton(onPressed: _canNext && !_busy ? _next : null, child: const Text('다음'))
                else
                  FilledButton(onPressed: _canNext && !_busy ? _submit : null, child: const Text('제출')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _page() => switch (_step) {
        0 => _searchStep(),
        1 => _receiptStep(),
        2 => _tierStep(),
        3 => _compareStep(),
        4 => _eventStep(),
        _ => _textStep(),
      };

  Widget _searchStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  decoration: const InputDecoration(labelText: '식당 이름', border: OutlineInputBorder()),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _search, child: const Text('검색')),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in _results)
            ListTile(
              selected: _place?.placeId == p.placeId,
              title: Text(p.name),
              subtitle: Text(p.region == null ? '베타 지역 아님' : p.address),
              trailing: _place?.placeId == p.placeId ? const Icon(Icons.check) : null,
              onTap: () => setState(() => _place = p),
            ),
        ],
      );

  Widget _receiptStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_place?.name ?? ''} 영수증을 올려 주세요', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('방문 후 30일 이내 영수증만 인증돼요. 인증이 끝나면 영수증 원본은 30일 뒤 자동 삭제돼요.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.receipt_long),
            label: const Text('영수증 사진 선택'),
            onPressed: () async {
              final f = await ref.read(imagePickerProvider)();
              if (f != null && mounted) setState(() => _receipt = f);
            },
          ),
          if (_receipt != null) const Padding(padding: EdgeInsets.only(top: 8), child: Text('영수증 선택됨')),
        ],
      );

  Widget _tierStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_place?.name ?? ''}, 어땠나요?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('리뷰 이벤트 서비스와 상관없이, 솔직한 느낌으로 골라 주세요.'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              for (final t in Tier.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: _tier == t,
                  onSelected: (_) => setState(() {
                    _tier = t;
                    _session = null;
                  }),
                ),
            ],
          ),
        ],
      );

  Widget _compareStep() {
    final s = _session;
    if (s == null) return const SizedBox.shrink();
    if (s.candidates.isEmpty) return const Text('같은 등급에 비교할 식당이 아직 없어요');
    if (s.done) return Text('순위가 정해졌어요 (${_tier!.label} 등급 ${s.index + 1}번째)');
    final cur = s.current!;
    final curName = _names[cur]?.name ?? cur;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('"$curName"와(과) 비교해 주세요', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => s.answer(newIsBetter: true)),
          child: const Text('이번 식당이 더 좋았어요'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => setState(() => s.answer(newIsBetter: false)),
          child: const Text('비교 식당이 더 좋았어요'),
        ),
      ],
    );
  }

  Widget _eventStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('리뷰 이벤트에 참여했나요?'),
            subtitle: const Text('음료·서비스를 받고 리뷰를 쓴 적이 있다면 켜 주세요. 솔직하게 알려 주실수록 찐점수가 정확해져요.'),
            value: _eventJoined,
            onChanged: (v) => setState(() => _eventJoined = v),
          ),
          if (_eventJoined) ...[
            const SizedBox(height: 8),
            const Text('이벤트 때 준 별점'),
            Row(
              children: [
                for (var n = 1; n <= 5; n++)
                  IconButton(
                    key: Key('star-$n'),
                    icon: Icon(n <= _stars ? Icons.star : Icons.star_border),
                    onPressed: () => setState(() => _stars = n),
                  ),
              ],
            ),
          ],
        ],
      );

  Widget _textStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _text,
            maxLength: 300,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '한줄평', helperText: '10자 이상', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('사진 추가'),
            onPressed: () async {
              final picked = await ref.read(photosPickerProvider)();
              if (picked.isNotEmpty && mounted) setState(() => _photos = picked.take(5).toList());
            },
          ),
          if (_photos.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('사진 ${_photos.length}장 선택됨')),
        ],
      );
}
