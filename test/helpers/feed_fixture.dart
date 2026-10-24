import 'dart:convert';

/// Recorded gateway response, shared by VM and browser tests.
Map<String, dynamic> readFeedResponse() =>
    jsonDecode(_feedResponseJson) as Map<String, dynamic>;

const _feedResponseJson =
    r'''{"weight_kg":350.0,"target":"penggemukan","total_dry_matter_kg":8.75,"recommendation":{"rumput":{"ratio_dm":45.0,"dry_matter_kg":3.94,"as_fed_kg":22.0},"jerami":{"ratio_dm":15.0,"dry_matter_kg":1.31,"as_fed_kg":1.4},"dedak":{"ratio_dm":40.0,"dry_matter_kg":3.5,"as_fed_kg":3.9}},"warning":null,"notes":["Air minum harus selalu tersedia.","Mineral/garam tetap diperlukan.","Naikkan porsi dedak secara bertahap selama masa adaptasi."]}''';
