// Browser-only adapter selected by the conditional export in local_storage.dart.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String?> readData() async => html.window.localStorage['cattle_mvp_v1'];
Future<void> writeData(String value) async {
  html.window.localStorage['cattle_mvp_v1'] = value;
}
