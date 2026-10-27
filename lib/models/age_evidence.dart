enum AgeCertainty { exact, estimated, unknown }

/// ageMonths remains the entered observation; a birthday is never inferred.
class AgeEvidence {
  const AgeEvidence({this.certainty = AgeCertainty.estimated, this.birthDate});
  final AgeCertainty certainty;
  final String? birthDate;
  Map<String, dynamic> toJson() => {
        'certainty': certainty.name,
        if (birthDate != null) 'birthDate': birthDate,
      };
  factory AgeEvidence.fromJson(Map<String, dynamic> json) {
    if (json.keys.any((k) => !{'certainty', 'birthDate'}.contains(k))) {
      throw const FormatException('Metadata usia belum didukung.');
    }
    final value = AgeEvidence(
        certainty: AgeCertainty.values.byName(json['certainty'] as String),
        birthDate: json['birthDate'] as String?);
    value.validate();
    return value;
  }
  void validate() {
    final birthday = birthDate;
    if (certainty == AgeCertainty.exact && birthday == null ||
        certainty == AgeCertainty.unknown && birthday != null) {
      throw const FormatException('Kepastian usia tidak sesuai tanggal lahir.');
    }
    if (birthday != null) {
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(birthday)) {
        throw const FormatException(
            'Tanggal lahir harus berupa tanggal kalender.');
      }
      final parsed = DateTime.parse(birthday);
      if (parsed.toIso8601String().substring(0, 10) != birthday) {
        throw const FormatException('Tanggal lahir tidak valid.');
      }
    }
  }
}
