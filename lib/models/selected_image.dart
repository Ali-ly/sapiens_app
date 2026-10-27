import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class SelectedImage {
  SelectedImage({
    required this.file,
    required Uint8List bytes,
    String? name,
    this.id,
  })  : name = name ?? file.name,
        bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  // XFile.fromData does not retain a supplied filename on every platform.
  final String? id;
  SelectedImage._(
      {required this.file,
      required this.bytes,
      required this.name,
      required this.id});
  SelectedImage withId(String value) =>
      SelectedImage._(file: file, bytes: bytes, name: name, id: value);
  final String name;
  final XFile file;
  final Uint8List bytes;
}
