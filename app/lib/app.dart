import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'ui/theme.dart';

class ZzinApp extends ConsumerWidget {
  const ZzinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '찐후기',
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
