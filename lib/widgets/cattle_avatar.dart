import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/cattle.dart';

class CattleAvatar extends StatelessWidget {
  const CattleAvatar({super.key, required this.cattle, this.size = 58});
  final Cattle cattle;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(size * .3),
        ),
        clipBehavior: Clip.antiAlias,
        child: cattle.images.isNotEmpty
            ? Image.memory(
                cattle.images.first.bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    CustomPaint(painter: CowPortrait()),
              )
            : CustomPaint(painter: CowPortrait()),
      );
}

class CowPortrait extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final horn = Paint()..color = const Color(0xFFBAC7A4);
    final face = Paint()..color = const Color(0xFFF8FAEE);
    final ink = Paint()..color = AppColors.primaryDark;
    final ears = Paint()..color = const Color(0xFF84966A);
    canvas.drawOval(const Rect.fromLTWH(8, 29, 29, 15), ears);
    canvas.drawOval(const Rect.fromLTWH(63, 29, 29, 15), ears);
    final left = Path()
      ..moveTo(33, 35)
      ..quadraticBezierTo(14, 28, 25, 16)
      ..quadraticBezierTo(24, 29, 40, 29)
      ..close();
    canvas.drawPath(left, horn);
    final right = Path()
      ..moveTo(67, 35)
      ..quadraticBezierTo(86, 28, 75, 16)
      ..quadraticBezierTo(76, 29, 60, 29)
      ..close();
    canvas.drawPath(right, horn);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(27, 28, 46, 49),
        const Radius.circular(19),
      ),
      face,
    );
    canvas.drawOval(const Rect.fromLTWH(26, 57, 48, 24), horn);
    canvas.drawCircle(const Offset(39, 48), 2.8, ink);
    canvas.drawCircle(const Offset(61, 48), 2.8, ink);
    canvas.drawOval(const Rect.fromLTWH(37, 66, 5, 4), ink);
    canvas.drawOval(const Rect.fromLTWH(58, 66, 5, 4), ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
