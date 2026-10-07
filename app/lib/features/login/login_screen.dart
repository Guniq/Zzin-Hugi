import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('찐후기', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 4),
                const Text('리뷰 이벤트 없이 쓴 진짜 후기', textAlign: TextAlign.center),
                const SizedBox(height: 32),
                const OutlinedButton(onPressed: null, child: Text('카카오로 시작하기 (준비 중)')),
                const SizedBox(height: 8),
                const OutlinedButton(onPressed: null, child: Text('Apple로 시작하기 (준비 중)')),
                const Divider(height: 40),
                const Text('개발용 테스트 로그인 (에뮬레이터)', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nick,
                  maxLength: 10,
                  decoration: InputDecoration(labelText: '닉네임', errorText: _error, border: const OutlineInputBorder()),
                  onSubmitted: (_) => _login(),
                ),
                FilledButton(onPressed: _busy ? null : _login, child: const Text('테스트 로그인')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
