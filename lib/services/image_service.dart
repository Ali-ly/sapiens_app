import 'package:image_picker/image_picker.dart';

import '../models/selected_image.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();
  Future<List<SelectedImage>> pickImages() async {
    final files = await _picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    return Future.wait(
      files.map(
        (file) async =>
            SelectedImage(file: file, bytes: await file.readAsBytes()),
      ),
    );
  }

  Future<SelectedImage?> takePhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    return file == null
        ? null
        : SelectedImage(file: file, bytes: await file.readAsBytes());
  }
}
