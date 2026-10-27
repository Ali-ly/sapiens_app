import 'package:flutter/material.dart';

/// A single, scalable cattle glyph shared by navigation and photo placeholders.
class CowMark extends StatelessWidget {
  const CowMark({super.key, this.size = 24, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
              painter: _CowPainter(
                  color ?? IconTheme.of(context).color ?? Colors.black))));
}

class _CowPainter extends CustomPainter {
  const _CowPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 32, size.height / 32);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
        Path()
          ..moveTo(10, 8)
          ..quadraticBezierTo(7, 7, 7, 3)
          ..moveTo(22, 8)
          ..quadraticBezierTo(25, 7, 25, 3),
        stroke);
    canvas.drawPath(
        Path()
          ..moveTo(9, 10)
          ..quadraticBezierTo(5, 7, 2, 11)
          ..quadraticBezierTo(4, 15, 9, 14)
          ..moveTo(23, 10)
          ..quadraticBezierTo(27, 7, 30, 11)
          ..quadraticBezierTo(28, 15, 23, 14),
        stroke);
    canvas.drawPath(
        Path()
          ..moveTo(10, 7)
          ..quadraticBezierTo(16, 5, 22, 7)
          ..quadraticBezierTo(25, 10, 22, 18)
          ..lineTo(21, 25)
          ..quadraticBezierTo(16, 31, 11, 25)
          ..lineTo(10, 18)
          ..quadraticBezierTo(7, 10, 10, 7)
          ..close(),
        stroke);
    final dot = Paint()..color = color;
    for (final p in const [
      Offset(12, 13),
      Offset(20, 13),
      Offset(14, 24),
      Offset(18, 24)
    ]) {
      canvas.drawCircle(p, .85, dot);
    }
  }

  @override
  bool shouldRepaint(_CowPainter oldDelegate) => color != oldDelegate.color;
}
