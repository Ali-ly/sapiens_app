import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class SelectedImage {
  SelectedImage({
    required this.file,
    required Uint8List bytes,
  }) : bytes = Uint8List.fromList(bytes);

  final XFile file;
  final Uint8List bytes;
}