import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../domain/cattle.dart';
import 'cow_mark.dart';

class CowAvatar extends StatelessWidget {
  const CowAvatar({super.key, required this.cattle, this.size = 58});
  final Cattle cattle;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(size * .24),
      child: cattle.photos.isNotEmpty
          ? Image.memory(cattle.photos.last.bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder)
          : placeholder);
  Widget get placeholder => Container(
      width: size,
      height: size,
      color: Palette.leaf,
      alignment: Alignment.center,
      child: CowMark(size: size * .52, color: Palette.ink));
}
