import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models.dart';
import '../../domain/score.dart';
import '../../ui/gauge.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({super.key, required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final hasScore = r.realScore != null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/r/${r.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                        Text(r.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(r.address, style: const TextStyle(fontSize: 13, color: AppColors.sub)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('찐점수', style: TextStyle(fontSize: 12, color: AppColors.sub)),
                      Text(
                        scoreText(r.realScore),
                        style: TextStyle(
                          fontSize: hasScore ? 28 : 14,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          color: hasScore ? AppColors.ink : AppColors.sub,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              BubbleGauge(real: r.realScore, event: r.eventScore),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (r.bubble != null) BubbleBadge('거품 ${bubbleText(r.bubble)}'),
                  if (r.eventScore != null)
                    Text('이벤트 ${scoreText(r.eventScore)}', style: const TextStyle(fontSize: 13, color: AppColors.sub)),
                  Text('후기 ${r.reviewCount}', style: const TextStyle(fontSize: 13, color: AppColors.sub)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
