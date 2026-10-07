import 'package:flutter/material.dart';

import '../../domain/models.dart';

class WriteReviewScreen extends StatelessWidget {
  const WriteReviewScreen({super.key, this.initialPlace});
  final PlaceResult? initialPlace;
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('후기 쓰기')));
}
