import 'dart:convert';
import 'dart:io';

/// A recorded gateway response; tests do not depend on the live service.
Map<String, dynamic> readFeedResponse() =>
    jsonDecode(File('test/fixtures/feed_response.json').readAsStringSync())
        as Map<String, dynamic>;
