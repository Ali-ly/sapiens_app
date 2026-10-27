import 'value.dart';

sealed class Condition {
  const Condition();
  Json toJson();
  static Condition fromJson(Json j) {
    final kind = j['kind'];
    return switch (kind) {
      'beef' => BeefCondition.fromJson(j),
      'dairy' => DairyCondition.fromJson(j),
      _ => throw const FormatException('Jenis kondisi tidak didukung.')
    };
  }
}

class BeefCondition extends Condition {
  const BeefCondition(
      {required this.purpose,
      this.phase,
      this.pregnancy,
      this.targetAdg,
      this.gestationMonth});
  final BeefPurpose purpose;
  final FatteningPhase? phase;
  final Pregnancy? pregnancy;
  final double? targetAdg, gestationMonth;
  @override
  Json toJson() => {
        'kind': 'beef',
        'purpose': purpose.name,
        'phase': phase?.name,
        'pregnancy': pregnancy?.name,
        'targetAdg': targetAdg,
        'gestationMonth': gestationMonth
      };
  factory BeefCondition.fromJson(Json j) {
    known(j, {
      'kind',
      'purpose',
      'phase',
      'pregnancy',
      'targetAdg',
      'gestationMonth'
    });
    return BeefCondition(
        purpose: BeefPurpose.values.byName(j['purpose'] as String),
        phase: j['phase'] == null
            ? null
            : FatteningPhase.values.byName(j['phase'] as String),
        pregnancy: j['pregnancy'] == null
            ? null
            : Pregnancy.values.byName(j['pregnancy'] as String),
        targetAdg: (j['targetAdg'] as num?)?.toDouble(),
        gestationMonth: (j['gestationMonth'] as num?)?.toDouble());
  }
}

class DairyCondition extends Condition {
  const DairyCondition(
      {this.stage,
      this.parity,
      this.bcs,
      this.milkFat,
      this.milkProtein,
      this.milkLactose,
      this.weeksToCalving,
      this.rationNdf,
      this.isHeifer});
  final DairyStage? stage;
  final int? parity;
  final double? bcs,
      milkFat,
      milkProtein,
      milkLactose,
      weeksToCalving,
      rationNdf;
  final bool? isHeifer;
  @override
  Json toJson() => {
        'kind': 'dairy',
        'stage': stage?.name,
        'parity': parity,
        'bcs': bcs,
        'milkFat': milkFat,
        'milkProtein': milkProtein,
        'milkLactose': milkLactose,
        'weeksToCalving': weeksToCalving,
        'rationNdf': rationNdf,
        'isHeifer': isHeifer
      };
  factory DairyCondition.fromJson(Json j) {
    known(j, {
      'kind',
      'stage',
      'parity',
      'bcs',
      'milkFat',
      'milkProtein',
      'milkLactose',
      'weeksToCalving',
      'rationNdf',
      'isHeifer'
    });
    double? n(String k) => (j[k] as num?)?.toDouble();
    return DairyCondition(
        stage: j['stage'] == null
            ? null
            : DairyStage.values.byName(j['stage'] as String),
        parity: j['parity'] as int?,
        bcs: n('bcs'),
        milkFat: n('milkFat'),
        milkProtein: n('milkProtein'),
        milkLactose: n('milkLactose'),
        weeksToCalving: n('weeksToCalving'),
        rationNdf: n('rationNdf'),
        isHeifer: j['isHeifer'] as bool?);
  }
}

class ConditionRecord {
  const ConditionRecord(
      {required this.id,
      required this.value,
      required this.effectiveAt,
      required this.createdAt});
  final String id;
  final Condition value;
  final DateTime effectiveAt, createdAt;
  Json toJson() => {
        'id': id,
        'value': value.toJson(),
        'effectiveAt': effectiveAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String()
      };
  factory ConditionRecord.fromJson(Json j) {
    known(j, {'id', 'value', 'effectiveAt', 'createdAt'});
    return ConditionRecord(
        id: j['id'] as String,
        value: Condition.fromJson(object(j['value'])),
        effectiveAt: instant(j['effectiveAt']),
        createdAt: instant(j['createdAt']));
  }
}

void validateCondition(Condition c, FarmMode mode, Sex sex) {
  require(
      (mode == FarmMode.beef && c is BeefCondition) ||
          (mode == FarmMode.dairy && c is DairyCondition),
      'Kondisi tidak sesuai mode akun.');
  if (c is BeefCondition) {
    require(c.purpose != BeefPurpose.fattening || c.phase != null,
        'Pilih fase penggemukan.');
    require(c.purpose != BeefPurpose.breeding || c.phase == null,
        'Pembibitan tidak memakai fase penggemukan.');
    require(
        c.purpose == BeefPurpose.breeding && sex == Sex.female ||
            c.pregnancy == null,
        'Status reproduksi hanya untuk betina pembibitan.');
    require(
        c.purpose != BeefPurpose.breeding ||
            sex != Sex.female ||
            c.pregnancy != null,
        'Pilih status reproduksi.');
    if (c.targetAdg != null) {
      positive(c.targetAdg, 'Target kenaikan berat', zero: true);
    }
    if (c.gestationMonth != null) {
      positive(c.gestationMonth, 'Bulan kebuntingan', zero: true);
    }
  } else if (c is DairyCondition) {
    require(
        sex == Sex.male
            ? c
                .toJson()
                .entries
                .where((e) => e.key != 'kind')
                .every((e) => e.value == null)
            : c.stage != null,
        'Data fisiologis perah hanya untuk betina; pilih fase bila betina.');
    if (c.parity != null) {
      require(c.parity! > 0, 'Nomor laktasi harus lebih dari nol.');
    }
    if (c.bcs != null) {
      require(c.bcs!.isFinite && c.bcs! >= 1 && c.bcs! <= 5,
          'BCS harus 1–5 sesuai kontrak backend.');
    }
    for (final n in [c.milkFat, c.milkProtein, c.milkLactose, c.rationNdf]) {
      if (n != null) positive(n, 'Nilai komposisi');
    }
    if (c.weeksToCalving != null) {
      positive(c.weeksToCalving, 'Minggu menuju kelahiran', zero: true);
    }
  }
}
