import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<File> _file() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/sapiens_rebuild/account-v1.json');
}

Future<String?> read() async {
  final file = await _file();
  return await file.exists() ? file.readAsString() : null;
}

Future<void> write(String value) async {
  final file = await _file();
  await file.parent.create(recursive: true);
  final temp = File('${file.path}.pending');
  await temp.writeAsString(value, flush: true);
  await temp.rename(file.path);
}
