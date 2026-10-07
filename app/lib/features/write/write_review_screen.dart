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
import '../../ui/theme.dart';

class WriteReviewScreen extends ConsumerStatefulWidget {
  const WriteReviewScreen({super.key, this.initialPlace});
  final PlaceResult? initialPlace;

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  static const _lastStep = 5;
  static const _eyebrows = ['식당 찾기', '영수증 인증', '솔직한 느낌', '순위 정하기', '리뷰 이벤트', '한줄평'];

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
  bool _searching = false;
  bool _searched = false;
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
    setState(() {
      _error = null;
      _searching = true;
    });
    try {
      final r = await ref.read(backendProvider).searchPlaces(q);
      if (mounted) {
        setState(() {
          _results = r;
          _searched = true;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = reviewErrorText(e.message));
    } catch (_) {
      if (mounted) setState(() => _error = reviewErrorText(null));
    } finally {
      if (mounted) setState(() => _searching = false);
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

  void _close() => context.canPop() ? context.pop() : context.go('/');

  @override
  Widget build(BuildContext context) {
    final first = widget.initialPlace == null ? 0 : 1;
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(tooltip: '닫기', onPressed: _close, icon: const Icon(Icons.close)),
                  const Text('후기 쓰기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${_step + 1} / ${_lastStep + 1}', style: const TextStyle(fontSize: 13, color: AppColors.sub)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  for (var i = 0; i <= _lastStep; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i == _lastStep ? 0 : 4),
                        decoration: BoxDecoration(
                          color: i <= _step ? AppColors.ink : AppColors.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_eyebrows[_step], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent)),
                    const SizedBox(height: 6),
                    _page(),
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  if (_step > first) ...[
                    OutlinedButton(
                      onPressed: _busy ? null : () => setState(() => _step--),
                      child: const Text('이전'),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: _step < _lastStep
                        ? FilledButton(onPressed: _canNext && !_busy ? _next : null, child: const Text('다음'))
                        : FilledButton(onPressed: _canNext && !_busy ? _submit : null, child: const Text('제출')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(String title, [String? sub]) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.3)),
          if (sub != null) ...[
            const SizedBox(height: 10),
            Text(sub, style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.sub)),
          ],
        ],
      );

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
          _heading('어느 식당에\n다녀오셨나요?'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: '식당 이름',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _searching ? null : _search, child: const Text('검색')),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('성수 주변을 먼저 보여 드려요. 지역 이름도 함께 검색하면 더 정확해요.', style: TextStyle(fontSize: 13, color: AppColors.sub)),
          ),
          const SizedBox(height: 16),
          if (_searching)
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
          else if (_searched && _results.isEmpty && _error == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('검색 결과가 없어요', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          for (final p in _results) _PlaceTile(place: p, selected: _place?.placeId == p.placeId, onTap: () => setState(() => _place = p)),
          if (_searched && _results.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '찾는 식당이 없나요? 이름을 조금 다르게 검색해 보세요. 지금은 성수 지역 식당만 후기를 쓸 수 있어요.',
                style: TextStyle(fontSize: 13, height: 1.55, color: AppColors.sub),
              ),
            ),
        ],
      );

  Widget _receiptStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            '${_place?.name ?? ''}\n영수증을 올려 주세요',
            '방문한 사람만 후기를 쓸 수 있어요. 이벤트로 받은 서비스가 있어도 괜찮아요. 뒤에서 솔직하게 알려 주세요.',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.ground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _receipt == null ? AppColors.border : AppColors.ink, width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, size: 48, color: AppColors.ink),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_receipt != null)
                        const Row(
                          children: [
                            Icon(Icons.check, size: 20, color: AppColors.ok),
                            SizedBox(width: 6),
                            Text('영수증 선택됨', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      if (_receipt != null) const SizedBox(height: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44)),
                        onPressed: () async {
                          final f = await ref.read(imagePickerProvider)();
                          if (f != null && mounted) setState(() => _receipt = f);
                        },
                        child: const Text('영수증 사진 선택'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _Fact('30일', '방문 후 30일 이내 영수증만 인증돼요'),
          const _Fact('삭제', '인증이 끝나면 영수증 원본은 30일 뒤 자동 삭제돼요'),
          const _Fact('1회', '같은 영수증은 한 번만 쓸 수 있어요'),
        ],
      );

  Widget _tierStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            '${_place?.name ?? ''},\n어땠나요?',
            '리뷰 이벤트 서비스와 상관없이, 솔직한 느낌으로 골라 주세요.',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            children: [
              for (final t in Tier.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: _tier == t,
                  showCheckmark: false,
                  selectedColor: AppColors.ink,
                  backgroundColor: AppColors.card,
                  labelStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _tier == t ? Colors.white : AppColors.ink,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
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
    if (s.candidates.isEmpty) {
      return _heading('같은 등급에 비교할 식당이 아직 없어요', '이 식당이 첫 번째로 기록돼요.');
    }
    if (s.done) {
      return _heading('순위가 정해졌어요 (${_tier!.label} 등급 ${s.index + 1}번째)');
    }
    final cur = s.current!;
    final curName = _names[cur]?.name ?? cur;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('어느 쪽이\n더 좋았나요?', '별점 대신 비교로 순위를 정해요. 더 좋았던 쪽을 눌러 주세요.'),
        const SizedBox(height: 24),
        _CompareCard(
          dark: true,
          caption: '방금 다녀온 식당',
          name: _place?.name ?? '',
          action: '이번 식당이 더 좋았어요',
          onTap: () => setState(() => s.answer(newIsBetter: true)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('VS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.sub))),
              Expanded(child: Divider()),
            ],
          ),
        ),
        _CompareCard(
          dark: false,
          caption: '내가 이미 평가한 식당',
          name: curName,
          action: '비교 식당이 더 좋았어요',
          onTap: () => setState(() => s.answer(newIsBetter: false)),
        ),
      ],
    );
  }

  Widget _eventStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            '리뷰 이벤트에\n참여했나요?',
            '음료·서비스를 받고 리뷰를 쓴 적이 있다면 알려 주세요. 솔직하게 알려 주실수록 이 식당의 찐점수가 정확해져요.',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(color: AppColors.ground, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Expanded(child: Text('이벤트에 참여했어요', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                Switch(value: _eventJoined, onChanged: (v) => setState(() => _eventJoined = v)),
              ],
            ),
          ),
          if (_eventJoined) ...[
            const SizedBox(height: 20),
            const Text('이벤트 때 준 별점', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(
              children: [
                for (var n = 1; n <= 5; n++)
                  IconButton(
                    key: Key('star-$n'),
                    iconSize: 36,
                    color: AppColors.accent,
                    icon: Icon(n <= _stars ? Icons.star : Icons.star_border),
                    onPressed: () => setState(() => _stars = n),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(16)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('이 점수는 거품지수에만 쓰여요', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accentText)),
                SizedBox(height: 4),
                Text('이벤트 별점과 내가 매긴 순위의 차이로 이 식당의 거품이 계산돼요. 내 찐점수에는 영향이 없어요.', style: TextStyle(fontSize: 14, height: 1.55)),
              ],
            ),
          ),
        ],
      );

  Widget _textStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('한줄로 남겨 주세요', '10자 이상 적어 주세요. 사진은 선택이에요.'),
          const SizedBox(height: 20),
          TextField(
            controller: _text,
            maxLength: 300,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '한줄평', helperText: '10자 이상'),
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

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.text);
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 44, child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.sub))),
          ],
        ),
      );
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.dark, required this.caption, required this.name, required this.action, required this.onTap});
  final bool dark;
  final String caption;
  final String name;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.ink;
    final sub = dark ? const Color(0xFFC9CDD2) : AppColors.sub;
    return Material(
      color: dark ? AppColors.ink : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: dark ? AppColors.ink : AppColors.border, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(caption, style: TextStyle(fontSize: 12, color: sub)),
              const SizedBox(height: 4),
              Text(name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: fg)),
              const SizedBox(height: 6),
              Text(action, style: TextStyle(fontSize: 14, color: sub)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place, required this.selected, required this.onTap});
  final PlaceResult place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final blocked = place.region == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: blocked ? AppColors.ground : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppColors.ink : (blocked ? AppColors.border : AppColors.line),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            place.name,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: blocked ? AppColors.sub : AppColors.ink),
                          ),
                          if (place.category.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: blocked ? AppColors.card : AppColors.ground,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(place.category, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(place.address, style: const TextStyle(fontSize: 13, color: AppColors.sub)),
                    ],
                  ),
                ),
                if (blocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(12)),
                    child: const Text('베타 지역 아님', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.sub)),
                  )
                else if (selected)
                  const Icon(Icons.check, color: AppColors.ok),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
