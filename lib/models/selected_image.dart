import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class SelectedImage {
  const SelectedImage({required this.file, required this.bytes});

  final XFile file;
  final Uint8List bytes;
}
