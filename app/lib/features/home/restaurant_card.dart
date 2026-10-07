import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models.dart';
import '../../domain/score.dart';

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({super.key, required this.restaurant});
  final Restaurant restaurant;

  Color _bubbleColor(BuildContext context) => switch (bubbleLevel(restaurant.bubble)) {
        BubbleLevel.high => Colors.red.shade100,
        BubbleLevel.mid => Colors.orange.shade100,
        _ => Theme.of(context).colorScheme.surfaceContainerHighest,
      };

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => context.push('/r/${r.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(r.address, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(label: Text('찐 ${scoreText(r.realScore)}'), visualDensity: VisualDensity.compact),
                  if (r.eventScore != null)
                    Chip(label: Text('이벤트 ${scoreText(r.eventScore)}'), visualDensity: VisualDensity.compact),
                  if (r.bubble != null)
                    Chip(
                      label: Text('거품 ${bubbleText(r.bubble)}'),
                      backgroundColor: _bubbleColor(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  Chip(label: Text('후기 ${r.reviewCount}'), visualDensity: VisualDensity.compact),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
