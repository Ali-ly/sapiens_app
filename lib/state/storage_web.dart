import 'dart:html' as html;

Future<String?> readData() async => html.window.localStorage['cattle_mvp_v1'];
Future<void> writeData(String value) async {
  html.window.localStorage['cattle_mvp_v1'] = value;
}
