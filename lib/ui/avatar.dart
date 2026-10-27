import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../domain/cattle.dart';

class CowAvatar extends StatelessWidget {
  const CowAvatar({super.key, required this.cattle, this.size = 58});
  final Cattle cattle;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(size * .3),
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
      child: Icon(Icons.pets_outlined, size: size * .45, color: Palette.ink));
}
