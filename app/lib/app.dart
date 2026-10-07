import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class JjinApp extends ConsumerWidget {
  const JjinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '찐후기',
      theme: ThemeData(colorSchemeSeed: const Color(0xFFE8590C), useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('찐후기'))),
    );
  }
}
