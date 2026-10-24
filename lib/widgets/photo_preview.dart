import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/selected_image.dart';

/// Keeps model bytes immutable while supplying a native typed array to web codecs.
class PhotoPreview extends StatefulWidget {
  const PhotoPreview(
      {super.key,
      required this.image,
      this.width,
      this.height,
      this.fit = BoxFit.cover,
      this.errorBuilder});
  final SelectedImage image;
  final double? width, height;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  State<PhotoPreview> createState() => _PhotoPreviewState();
}

class _PhotoPreviewState extends State<PhotoPreview> {
  late Uint8List _decodeBytes;

  @override
  void initState() {
    super.initState();
    _decodeBytes = Uint8List.fromList(widget.image.bytes);
  }

  @override
  void didUpdateWidget(covariant PhotoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.image, widget.image)) {
      _decodeBytes = Uint8List.fromList(widget.image.bytes);
    }
  }

  @override
  Widget build(BuildContext context) => Image.memory(
        _decodeBytes,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: widget.errorBuilder ??
            (context, error, stack) => const ColoredBox(
                  color: AppColors.surfaceSoft,
                  child: Center(
                      child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image_outlined,
                                  color: AppColors.textSecondary),
                              SizedBox(height: 8),
                              Text(
                                  'Foto tidak dapat dibuka.\nCoba JPG atau PNG lain.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          ))),
                ),
      );
}
