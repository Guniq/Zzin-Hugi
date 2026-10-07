import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../ui/gauge.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nick = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _nick.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final nick = _nick.text.trim();
    if (nick.isEmpty) {
      setState(() => _error = '닉네임을 입력해 주세요');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref.read(authServiceProvider).signInDebug(nick.length > 10 ? nick.substring(0, 10) : nick);
    } catch (e) {
      if (mounted) setState(() => _error = '로그인에 실패했어요: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _soon() => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아직 연결 전이에요. 아래 개발용 테스트 로그인을 이용해 주세요.')),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 48, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('찐후기', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -2, height: 1.05)),
                  const SizedBox(height: 6),
                  const Text('ZZIN HUGI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 3, color: AppColors.sub)),
                  const SizedBox(height: 28),
                  const Text('리뷰 이벤트 말고,\n영수증으로 확인한 찐 후기.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.4)),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    decoration: BoxDecoration(color: AppColors.ground, borderRadius: BorderRadius.circular(18)),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('화곡 찐고기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            Text('이벤트 별점 vs 찐점수', style: TextStyle(fontSize: 13, color: AppColors.sub)),
                          ],
                        ),
                        SizedBox(height: 16),
                        BubbleGauge(real: 2.3, event: 10),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Text('찐 2.3', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            SizedBox(width: 10),
                            Text('이벤트 10.0', style: TextStyle(fontSize: 13, color: AppColors.sub)),
                            SizedBox(width: 10),
                            BubbleBadge('거품 +7.7'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _soon,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFEE500), foregroundColor: const Color(0xFF191600)),
                    child: const Text('카카오로 시작하기 (준비 중)'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _soon,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white),
                    child: const Text('Apple로 시작하기 (준비 중)'),
                  ),
                  const SizedBox(height: 28),
                  const Text('개발용 테스트 로그인 (에뮬레이터)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.sub)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nick,
                    maxLength: 10,
                    decoration: InputDecoration(labelText: '닉네임', errorText: _error),
                    onSubmitted: (_) => _login(),
                  ),
                  OutlinedButton(onPressed: _busy ? null : _login, child: const Text('테스트 로그인')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
