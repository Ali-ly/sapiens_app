import 'package:flutter/material.dart';
import '../../app/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/contracts.dart';
import '../../application/providers.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';

class FeedInformation extends StatelessWidget {
  const FeedInformation({super.key, required this.feed});
  final FeedIngredient feed;
  @override
  Widget build(BuildContext context) {
    const fields = {
      'physical_form': 'Bentuk fisik',
      'dry_matter_pct_as_fed': 'Bahan kering (% pakan segar)',
      'crude_protein_pct_dm': 'Protein kasar (% bahan kering)',
      'tdn_pct_dm': 'TDN (% bahan kering)',
      'ndf_pct_dm': 'NDF (% bahan kering)',
      'adf_pct_dm': 'ADF (% bahan kering)',
      'calcium_pct_dm': 'Kalsium (% bahan kering)',
      'phosphorus_pct_dm': 'Fosfor (% bahan kering)',
      'confidence_note': 'Catatan keandalan data',
      'source_title': 'Sumber referensi',
      'source_profile_id': 'Referensi profil bahan',
      'quality_standard_id': 'Standar kualitas'
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(feed.name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Text('Status data: ${const {
            'ready': 'Profil tersedia',
            'conditional': 'Referensi / bersyarat',
            'product_specific': 'Spesifikasi produk diperlukan',
            'needs_verification': 'Perlu verifikasi'
          }[feed.profileStatus] ?? 'Belum diketahui'}'),
      if (feed.productSpecific)
        const Notice(
            'Bahan ini bergantung pada spesifikasi produk. Katalog saat ini tidak menyediakan input label/lab khusus; kekurangan data tetap ditampilkan, tanpa nilai nutrisi buatan.',
            warning: true),
      for (final e in fields.entries)
        if (feed.raw[e.key] != null)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.value,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(feed.raw[e.key].toString())
                  ])),
      const SizedBox(height: 16),
      const Text('Nilai yang tidak dikirim backend tidak dianggap nol.'),
    ]);
  }
}

class FeedCatalogPage extends ConsumerStatefulWidget {
  const FeedCatalogPage({super.key});
  @override
  ConsumerState<FeedCatalogPage> createState() => _FeedCatalogPageState();
}

class _FeedCatalogPageState extends ConsumerState<FeedCatalogPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(farmProvider).requireValue.account!.mode;
    final catalog = ref.watch(feedCatalogProvider(mode));
    return PageFrame(
        maxWidth: AppLayout.contentWidth,
        title: 'Daftar Bahan Pakan',
        subtitle: mode.label,
        children: [
          TextField(
              decoration: const InputDecoration(
                  labelText: 'Cari bahan', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => query = v)),
          const SizedBox(height: 16),
          catalog.when(
              loading: () => const LoadingState(),
              error: (e, _) => Column(children: [
                    Notice(errorText(e), error: true),
                    OutlinedButton(
                        onPressed: () =>
                            ref.invalidate(feedCatalogProvider(mode)),
                        child: const Text('Coba muat lagi'))
                  ]),
              data: (rows) {
                final filtered = rows
                    .where((f) =>
                        f.name.toLowerCase().contains(query.toLowerCase()))
                    .toList();
                if (filtered.isEmpty) {
                  return const EmptyMessage(
                      title: 'Bahan belum tersedia',
                      message:
                          'Tidak ada bahan yang cocok dari katalog layanan. Daftar tidak diisi dengan bahan hard-code.');
                }
                return Column(children: [
                  for (final f in filtered)
                    Surface(
                        padding: 8,
                        child: ExpansionTile(
                            title: Text(f.name),
                            subtitle: Text(f.productSpecific
                                ? 'Perlu spesifikasi produk'
                                : 'Data referensi layanan'),
                            childrenPadding: const EdgeInsets.all(14),
                            children: [FeedInformation(feed: f)]))
                ]);
              }),
        ]);
  }
}
