import 'dart:io';

File get _file {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  final root = Platform.isAndroid
      ? '${Directory.systemTemp.parent.path}/files'
      : home == null
          ? Directory.systemTemp.path
          : Platform.isIOS
              ? '$home/Documents/cattle_app'
              : '$home/.cattle_app';
  return File('$root/cattle_mvp_v1.json');
}

Future<String?> readData() async =>
    await _file.exists() ? _file.readAsString() : null;
Future<void> writeData(String value) async {
  final file = _file;
  await file.parent.create(recursive: true);
  final temp = File('${file.path}.tmp');
  await temp.writeAsString(value, flush: true);
  await temp.rename(file.path);
}
