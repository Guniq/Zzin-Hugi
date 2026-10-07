import 'package:flutter/material.dart';

import 'theme.dart';

/// 0~10 점수를 게이지 위치(0~1)로.
double gaugeFraction(double score) => (score / 10).clamp(0.0, 1.0);

/// 거품 게이지: 속이 찬 점 = 찐점수, 빈 점 = 이벤트 점수, 둘 사이 줄무늬 = 거품.
class BubbleGauge extends StatelessWidget {
  const BubbleGauge({super.key, required this.real, this.event});
  final double? real;
  final double? event;

  static const _dot = 20.0;
  static const _pad = _dot / 2;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _dot,
      child: LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - _dot).clamp(0.0, double.infinity);
        double x(double score) => _pad + w * gaugeFraction(score);
        final r = real;
        final e = event;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: _pad,
              right: _pad,
              top: 7,
              height: 6,
              child: const DecoratedBox(
                decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.all(Radius.circular(3))),
              ),
            ),
            if (r != null && e != null && e > r)
              Positioned(left: x(r), width: x(e) - x(r), top: 7, height: 6, child: const _Stripes()),
            if (r != null)
              Positioned(
                left: x(r) - _pad,
                top: 0,
                child: Container(
                  width: _dot,
                  height: _dot,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.card, width: 3),
                    boxShadow: const [BoxShadow(color: AppColors.ink, spreadRadius: 1)],
                  ),
                ),
              ),
            if (e != null)
              Positioned(
                left: x(e) - _pad,
                top: 0,
                child: Container(
                  width: _dot,
                  height: _dot,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 3),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _Stripes extends StatelessWidget {
  const _Stripes();
  @override
  Widget build(BuildContext context) => const CustomPaint(painter: _StripePainter());
}

class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.accentSoft);
    final p = Paint()
      ..color = AppColors.stripe
      ..strokeWidth = 3;
    for (double x = -size.height; x < size.width + size.height; x += 8) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
