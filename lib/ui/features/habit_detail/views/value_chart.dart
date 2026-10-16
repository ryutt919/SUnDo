import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

/// 수치 기록을 이어 그린 간단한 꺾은선 그래프.
class ValueChart extends StatelessWidget {
  const ValueChart({super.key, required this.points});
  final List<double> points;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ChartPainter(points, Theme.of(context).colorScheme.outlineVariant), size: Size.infinite);
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.points, this.gridColor);
  final List<double> points;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minV = points.reduce((a, b) => a < b ? a : b);
    final maxV = points.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;
    const pad = 8.0;
    Offset at(int i) => Offset(
          pad + (size.width - pad * 2) * i / (points.length - 1),
          size.height - pad - (size.height - pad * 2) * (points[i] - minV) / range,
        );

    final grid = Paint()..color = gridColor..strokeWidth = 1;
    for (var k = 0; k < 3; k++) {
      final y = pad + (size.height - pad * 2) * k / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final line = Paint()
      ..color = AppColors.green
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = AppColors.green;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(at(i), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.points != points;
}
