import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/cattle.dart';

class WeightChart extends CustomPainter {
  WeightChart(this.records);
  final List<WeightRecord> records;
  @override
  void paint(Canvas canvas, Size size) {
    if (records.length < 2) {
      return;
    }
    final values = records.map((r) => r.weightKg).toList();
    final min = values.reduce((a, b) => a < b ? a : b) - 10;
    final max = values.reduce((a, b) => a > b ? a : b) + 10;
    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final y = 10 + (size.height - 20) * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final first = records.first.date.millisecondsSinceEpoch;
    final span = records.last.date.millisecondsSinceEpoch - first;
    final points = List.generate(
      values.length,
      (i) => Offset(
        span == 0
            ? size.width * i / (values.length - 1)
            : size.width *
                (records[i].date.millisecondsSinceEpoch - first) /
                span,
        size.height - 10 - (values[i] - min) / (max - min) * (size.height - 20),
      ),
    );
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()..color = AppColors.primarySoft.withOpacity(.65),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 4, Paint()..color = AppColors.primary);
      if (i == 0 || i == points.length - 1) {
        final text = TextPainter(
          text: TextSpan(
            text: '${values[i].toStringAsFixed(0)} kg',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(
          canvas,
          Offset(
            (points[i].dx - text.width / 2)
                .clamp(0, size.width - text.width)
                .toDouble(),
            (points[i].dy - 22).clamp(0, size.height - text.height).toDouble(),
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant WeightChart oldDelegate) =>
      oldDelegate.records != records;
}
