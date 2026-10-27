import '../api/contracts.dart';
import '../domain/cattle.dart';
import '../domain/condition.dart';
import '../domain/milk_metrics.dart';
import '../domain/records.dart';
import '../domain/value.dart';

class NutritionContext {
  NutritionContext(this.mode, this.cattle, this.now);
  final FarmMode mode;
  final Cattle cattle;
  final DateTime now;
  final List<String> issues = [];
  bool capabilityLimited = false;
  Json get snapshot => {
        'mode': mode.name,
        'weight': cattle.latestWeight.toJson(),
        'condition': cattle.condition.toJson(),
        'sex': cattle.sex.name,
        'ageMonths': cattle.ageMonths,
        'milk': mode == FarmMode.dairy
            ? MilkMetrics(cattle, now).latest?.toJson()
            : null,
        'dim': mode == FarmMode.dairy ? MilkMetrics(cattle, now).dim : null,
        'events': cattle.events.map((e) => e.toJson()).toList(),
        'active': cattle.active
      };
  String get hash => fingerprint(snapshot);
  bool isCurrent(NutritionEvaluation e) =>
      e.contextHash == hash && !e.createdAt.isAfter(now);
  Json build() {
    issues.clear();
    capabilityLimited = false;
    if (!cattle.active) {
      issues.add(
          'Sapi berada di arsip. Aktifkan kembali untuk mengevaluasi pakan.');
    }
    final body = <String, dynamic>{'body_weight_kg': cattle.latestWeight.kg};
    final c = cattle.condition;
    if (c is BeefCondition) {
      body['purpose'] =
          c.purpose == BeefPurpose.fattening ? 'penggemukan' : 'pembibitan';
      if (c.purpose == BeefPurpose.breeding) {
        capabilityLimited = true;
        issues.add(
            'Backend Pembibitan belum diaktifkan. Kondisi tetap tercatat; tidak memakai rumus penggemukan sebagai pengganti.');
      }
      if (c.targetAdg == null) {
        if (c.purpose == BeefPurpose.fattening) {
          issues.add('Isi target kenaikan berat per hari di Perawatan.');
        }
      } else {
        body['target_adg_kg_day'] = c.targetAdg;
      }
    } else if (c is DairyCondition) {
      if (cattle.sex == Sex.male) {
        capabilityLimited = true;
        issues.add(
            'Backend belum menyediakan konteks nutrisi sapi perah jantan. Tidak memakai kalkulasi sapi potong sebagai pengganti.');
      } else if (c.stage == null) {
        issues.add('Pilih fase fisiologis di Perawatan.');
      } else {
        body['dairy_stage'] = c.stage!.wire;
        final metrics = MilkMetrics(cattle, now);
        if (c.stage!.lactating) {
          if (metrics.dim == null) {
            issues.add(
                'Catat kelahiran aktual agar hari laktasi (DIM) diketahui.');
          } else if (metrics.dim == 0) {
            capabilityLimited = true;
            issues.add(
                'Kelahiran tercatat hari ini (DIM 0). Kontrak backend saat ini hanya menerima DIM lebih dari nol.');
          } else {
            body['dim'] = metrics.dim;
          }
          final latest = metrics.latest;
          if (latest == null || !latest.complete) {
            issues.add(
                'Lengkapi produksi susu harian; sesi yang kosong tidak dianggap nol.');
          } else if (metrics.calving != null &&
              latest.date.compareTo(metrics.calving!.date) < 0) {
            issues.add(
                'Catat produksi susu setelah kelahiran terakhir. Catatan laktasi sebelumnya tetap tersimpan.');
          } else if (latest.unit != MilkUnit.kg) {
            issues.add(
                'Backend memerlukan berat susu dalam kg/hari. Catatan liter tidak dikonversi otomatis; catat hasil penimbangan dalam kg.');
          } else if (latest.recordedAmount <= 0) {
            issues.add(
                'Produksi susu tercatat nol. Backend laktasi memerlukan produksi lebih dari nol; catatan nol tetap dipertahankan.');
          } else {
            body['milk_kg_day'] = latest.recordedAmount;
          }
          if (metrics.parity == null) {
            issues
                .add('Isi nomor laktasi/paritas yang diketahui di Perawatan.');
          } else {
            body['parity_group'] =
                metrics.parity == 1 ? 'primiparous' : 'multiparous';
          }
          if (c.milkFat == null) {
            issues.add(
                'Isi persentase lemak susu dari hasil pengukuran di Perawatan. Backend memerlukannya untuk energi susu.');
          }
          if (c.bcs != null) body['bcs'] = c.bcs;
          if (c.milkFat != null) body['milk_fat_pct'] = c.milkFat;
          if (c.milkProtein != null) body['milk_protein_pct'] = c.milkProtein;
          if (c.milkLactose != null) body['milk_lactose_pct'] = c.milkLactose;
        } else if (c.stage == DairyStage.closeUp) {
          if (c.weeksToCalving == null) {
            issues.add(
                'Isi perkiraan minggu menuju kelahiran dari data pengguna/vet.');
          } else {
            body['weeks_to_calving'] = c.weeksToCalving;
          }
          if (c.rationNdf == null) {
            issues.add('Isi NDF ransum dari data yang diketahui.');
          } else {
            body['ration_ndf_pct_dm'] = c.rationNdf;
          }
          if (c.isHeifer == null) {
            issues.add(
                'Nyatakan apakah sapi ini dara yang belum pernah beranak.');
          } else {
            body['is_heifer'] = c.isHeifer;
          }
        } else {
          capabilityLimited = true;
          issues.add(
              'Fase ${c.stage!.label} dikenali, tetapi perhitungan kebutuhan pada source backend belum diaktifkan. Data sapi tetap bisa dicatat.');
        }
      }
    }
    return body;
  }

  Json request(List<FeedAmount> items, List<FeedIngredient> catalog) {
    final context = build();
    require(issues.isEmpty, issues.join('\n'));
    require(
        items.isNotEmpty &&
            items.map((e) => e.feedId).toSet().length == items.length,
        'Pilih bahan tanpa duplikasi.');
    for (final i in items) {
      positive(i.kg, 'Jumlah pakan');
      require(catalog.any((f) => f.id == i.feedId && f.validFor.contains(mode)),
          'Bahan tidak valid untuk jenis peternakan ini.');
    }
    return {
      'production_category': mode.name,
      'cattle': context,
      'feed_items': items.map((e) => e.toJson()).toList()
    };
  }
}
