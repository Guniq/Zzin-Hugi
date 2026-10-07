import 'package:flutter/material.dart';

import 'theme.dart';

/// 정렬·필터용 알약 버튼. 선택되면 먹색으로 채운다.
ChoiceChip pill(String label, {required bool selected, required VoidCallback onSelected}) => ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
      side: selected ? BorderSide.none : const BorderSide(color: AppColors.border),
      backgroundColor: AppColors.card,
      selectedColor: AppColors.ink,
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? Colors.white : AppColors.ink,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );

/// "거품 +7.7" 같은 빨간 알약 배지.
class BubbleBadge extends StatelessWidget {
  const BubbleBadge(this.text, {super.key, this.large = false});
  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 14 : 10, vertical: large ? 6 : 3),
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(16)),
        child: Text(text, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: large ? 15 : 13)),
      );
}

/// 원형 이니셜 아바타.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(this.name, {super.key, this.size = 36, this.color = AppColors.ink});
  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          name.isEmpty ? '찐' : name.characters.first,
          style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w900),
        ),
      );
}
