import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../api/contracts.dart';
import '../../domain/value.dart';

abstract interface class PhotoPicker {
  Future<List<UploadPhoto>> pick({required bool camera});
}

class DevicePhotoPicker implements PhotoPicker {
  final picker = ImagePicker();
  @override
  Future<List<UploadPhoto>> pick({required bool camera}) async {
    final files = camera
        ? [await picker.pickImage(source: ImageSource.camera)]
            .whereType<XFile>()
            .toList()
        : await picker.pickMultiImage();
    require(files.length <= 4, 'Pilih maksimal 4 foto dalam satu pengukuran.');
    final result = <UploadPhoto>[];
    for (final f in files) {
      final bytes = await f.readAsBytes();
      require(bytes.isNotEmpty && bytes.length <= 8 * 1024 * 1024,
          'Foto ${f.name} terlalu besar atau kosong. Maksimal 8 MB per foto.');
      final extension = f.name.contains('.')
          ? '.${f.name.split('.').last.toLowerCase()}'
          : '.jpg';
      result.add(
          UploadPhoto(name: '${const Uuid().v4()}$extension', bytes: bytes));
    }
    return result;
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => DevicePhotoPicker());
