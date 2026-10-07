import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/regions.dart';
import '../../../data/providers.dart';
import '../../../domain/errors.dart';
import '../../../domain/models.dart';
import '../../../domain/score.dart';
import '../../../ui/theme.dart';
import 'place_map.dart';

export 'place_map.dart';

/// 지도에서 식당을 찾아 고르는 화면. 검색 결과를 핀으로 찍고, 핀을 누르면 아래 카드에 정보가 뜬다.
class PlaceMapPicker extends ConsumerStatefulWidget {
  const PlaceMapPicker({super.key, required this.onPicked, required this.onClose, required this.onShowList});

  /// "이 식당 선택"을 눌렀을 때
  final ValueChanged<PlaceResult> onPicked;
  final VoidCallback onClose;

  /// 목록으로 보기(지도가 안 뜰 때 포함). 현재 검색어와 결과를 넘긴다.
  final void Function(String query, List<PlaceResult> results) onShowList;

  @override
  ConsumerState<PlaceMapPicker> createState() => _PlaceMapPickerState();
}

class _PlaceMapPickerState extends ConsumerState<PlaceMapPicker> {
  final _query = TextEditingController();
  PlaceMapHandle? _map;
  double _lat = betaRegions.first.lat;
  double _lng = betaRegions.first.lng;
  String _lastQuery = '';
  List<PlaceResult> _results = [];
  String? _selectedId;
  bool _searching = false;
  bool _searched = false;
  bool _showRefresh = false;
  bool _mapFailed = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  PlaceResult? get _selected {
    for (final p in _results) {
      if (p.placeId == _selectedId) return p;
    }
    return null;
  }

  List<MapMarkerData> get _markers => [
        for (final p in _results)
          if (p.lat != null && p.lng != null)
            MapMarkerData(id: p.placeId, lat: p.lat!, lng: p.lng!, name: p.name, blocked: p.region == null),
      ];

  Future<void> _search({required bool fit}) async {
    final q = fit ? _query.text.trim() : _lastQuery;
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _error = null;
      _showRefresh = false;
    });
    try {
      final r = await ref.read(backendProvider).searchPlaces(q, lat: _lat, lng: _lng);
      if (!mounted) return;
      setState(() {
        _lastQuery = q;
        _results = r;
        _searched = true;
        _selectedId = (r.where((p) => p.region != null).firstOrNull ?? r.firstOrNull)?.placeId;
      });
      await _map?.setMarkers(_markers, selectedId: _selectedId, fit: fit);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = reviewErrorText(e.message));
    } catch (_) {
      if (mounted) setState(() => _error = reviewErrorText(null));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _select(String id) {
    setState(() => _selectedId = id);
    _map?.setMarkers(_markers, selectedId: id);
  }

  void _onUserMoved(double lat, double lng) {
    if (!mounted) return;
    setState(() {
      _lat = lat;
      _lng = lng;
      _showRefresh = _lastQuery.isNotEmpty;
    });
  }

  Future<void> _locate() async {
    final p = await _map?.locate();
    if (!mounted) return;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('내 위치를 가져오지 못했어요. https 주소에서만 쓸 수 있어요.')));
      return;
    }
    await _map?.moveTo(p.lat, p.lng);
    if (!mounted) return;
    setState(() {
      _lat = p.lat;
      _lng = p.lng;
      _showRefresh = _lastQuery.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final builder = ref.watch(placeMapBuilderProvider);
    final sel = _selected;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: builder(
              context,
              lat: betaRegions.first.lat,
              lng: betaRegions.first.lng,
              onReady: (h) => _map = h,
              onMarkerTap: _select,
              onUserMoved: _onUserMoved,
              onError: (_) {
                if (mounted) setState(() => _mapFailed = true);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundButton(tooltip: '닫기', icon: Icons.close, onPressed: widget.onClose),
                      const SizedBox(width: 8),
                      Expanded(child: _SearchField(controller: _query, onSubmit: () => _search(fit: true), onChanged: () => setState(() {}))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_searching)
                    const _Pill(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4)))
                  else if (_showRefresh)
                    _Pill(
                      onTap: () => _search(fit: false),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, size: 18, color: AppColors.accent),
                          SizedBox(width: 8),
                          Text('이 지역에서 다시 검색', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accent)),
                        ],
                      ),
                    )
                  else if (!_searched && _error == null)
                    const _Pill(child: Text('식당 이름을 검색해 보세요', style: TextStyle(fontSize: 14, color: AppColors.sub))),
                  if (_error != null)
                    _Pill(child: Text(_error!, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.error))),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 14, bottom: 12),
                  child: _RoundButton(tooltip: '내 위치', icon: Icons.my_location, onPressed: _locate),
                ),
                if (_searched && _results.isEmpty && _error == null)
                  const _EmptySheet()
                else if (sel != null)
                  _PlaceSheet(
                    place: sel,
                    onPick: () => widget.onPicked(sel),
                    onList: () => widget.onShowList(_lastQuery, _results),
                  ),
              ],
            ),
          ),
          if (_mapFailed)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.ground,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('지도를 불러오지 못했어요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        const Text('목록으로 식당을 검색할 수 있어요.', style: TextStyle(color: AppColors.sub)),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => widget.onShowList(_query.text.trim(), const []),
                          child: const Text('목록으로 검색'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(onPressed: widget.onClose, child: const Text('닫기')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.tooltip, required this.icon, required this.onPressed});
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.card,
        shape: const CircleBorder(),
        elevation: 3,
        child: IconButton(
          tooltip: tooltip,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          icon: Icon(icon, color: AppColors.ink),
          onPressed: onPressed,
        ),
      );
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onSubmit, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.card,
        elevation: 3,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 48,
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSubmit(),
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: '식당 이름',
              filled: false,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              prefixIcon: const Icon(Icons.search, color: AppColors.sub),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '지우기',
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.sub),
                      onPressed: () {
                        controller.clear();
                        onChanged();
                      },
                    ),
            ),
          ),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: AppColors.card,
          elevation: 3,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      );
}

class _EmptySheet extends StatelessWidget {
  const _EmptySheet();

  @override
  Widget build(BuildContext context) => const _SheetShell(
        child: Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('검색 결과가 없어요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('이름을 조금 다르게 검색하거나, 지도를 옮겨서 다시 검색해 보세요.', style: TextStyle(fontSize: 14, color: AppColors.sub)),
            ],
          ),
        ),
      );
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Color(0x29121417), blurRadius: 20, offset: Offset(0, -4))],
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

class _PlaceSheet extends ConsumerWidget {
  const _PlaceSheet({required this.place, required this.onPick, required this.onList});
  final PlaceResult place;
  final VoidCallback onPick;
  final VoidCallback onList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = place.region == null;
    final stats = ref.watch(restaurantProvider(place.placeId)).value;
    return _SheetShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        Text(place.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        if (place.category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.ground, borderRadius: BorderRadius.circular(10)),
                            child: Text(place.category, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(place.address, style: const TextStyle(fontSize: 14, color: AppColors.sub)),
                  ],
                ),
              ),
              TextButton(
                onPressed: onList,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: AppColors.ink),
                child: const Text('목록 보기', style: TextStyle(fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
              ),
            ],
          ),
          if (stats != null && stats.reviewCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.ground, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Text('이 식당의 찐점수', style: TextStyle(fontSize: 12, color: AppColors.sub)),
                  const SizedBox(width: 8),
                  Text(scoreText(stats.realScore), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  Text('· 인증 후기 ${stats.reviewCount}개', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: blocked ? null : onPick, child: Text(blocked ? '베타 지역 아님' : '이 식당 선택')),
          ),
        ],
      ),
    );
  }
}
