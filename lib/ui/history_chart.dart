import 'package:flutter/material.dart';
import '../app/theme.dart';

class HistoryChart extends StatelessWidget {
  const HistoryChart(
      {super.key, required this.values, required this.description});
  final List<double> values;
  final String description;
  @override
  Widget build(BuildContext context) => Semantics(
      label: description,
      image: true,
      child: SizedBox(
          height: 150,
          width: double.infinity,
          child: CustomPaint(painter: _Chart(values))));
}

class _Chart extends CustomPainter {
  _Chart(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final min = values.reduce((a, b) => a < b ? a : b),
        max = values.reduce((a, b) => a > b ? a : b);
    final span = max == min ? 1.0 : max - min;
    final line = Paint()
      ..color = Palette.ink
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final point = Offset(8 + i * (size.width - 16) / (values.length - 1),
          size.height - 12 - (values[i] - min) / span * (size.height - 24));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawCircle(point, 3.5, Paint()..color = Palette.ink);
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _Chart old) => old.values != values;
}
