// Platform adapter is the only browser-specific boundary.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<dynamic> _database() async {
  final factory = html.window.indexedDB;
  if (factory == null) {
    throw StateError('Browser ini tidak menyediakan penyimpanan lokal.');
  }
  return factory.open('sapiens_rebuild', version: 1, onUpgradeNeeded: (e) {
    final db = e.target.result;
    db.createObjectStore('account');
  });
}

Future<String?> read() async {
  final db = await _database();
  try {
    final tx = db.transaction('account', 'readonly');
    final value = await tx.objectStore('account').getObject('snapshot');
    await tx.completed;
    return value as String?;
  } finally {
    db.close();
  }
}

Future<void> write(String value) async {
  final db = await _database();
  try {
    final tx = db.transaction('account', 'readwrite');
    await tx.objectStore('account').put(value, 'snapshot');
    await tx.completed;
  } finally {
    db.close();
  }
}
