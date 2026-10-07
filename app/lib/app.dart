import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

class ZzinApp extends ConsumerWidget {
  const ZzinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '찐후기',
      theme: ThemeData(colorSchemeSeed: const Color(0xFFE8590C), useMaterial3: true),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
