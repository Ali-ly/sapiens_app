import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/feed_plan.dart';
import '../../state/farm_store.dart';
import '../../services/feed_service.dart';
import '../../widgets/farm_ui.dart';
import '../cattle/add_cattle_screen.dart';
import '../cattle/cattle_profile_screen.dart';
import 'feed_result_screen.dart';

typedef FeedCalculation = Future<Map<String, dynamic>> Function(
    {required double weight,
    required String target,
    required List<String> availableFeeds});

class FeedCalculatorScreen extends StatefulWidget {
  const FeedCalculatorScreen({super.key, this.cattleId, this.calculate});
  final String? cattleId;
  final FeedCalculation? calculate;
  @override
  State<FeedCalculatorScreen> createState() => _FeedCalculatorScreenState();
}

class _FeedCalculatorScreenState extends State<FeedCalculatorScreen> {
  String? selected;
  String target = 'pemeliharaan', condition = 'Tidak tahu';
  Set<String> feeds = {'rumput'};
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final store = FarmStore.instance;
    selected = widget.cattleId ??
        (store.cattle.isEmpty ? null : store.cattle.first.id);
    final old = selected == null ? null : store.latestPlan(selected!);
    if (old != null) {
      target = old.target;
      condition = old.bodyCondition;
      feeds = old.availableFeeds.toSet();
    }
  }

  Future<void> calculate() async {
    final c = selected == null ? null : FarmStore.instance.byId(selected!);
    if (c == null || c.estimatedWeight == null) {
      setState(() =>
          error = 'Catat bobot sapi terlebih dahulu untuk menghitung pakan.');
      return;
    }
    if (feeds.isEmpty) {
      setState(() => error = 'Pilih minimal satu bahan pakan yang tersedia.');
      return;
    }
    if (!feeds.contains('rumput') && !feeds.contains('jerami')) {
      setState(() => error =
          'Tambahkan rumput hijauan atau jerami padi sebagai sumber serat. Dedak saja belum mencukupi.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    final currentTarget = target, currentCondition = condition;
    final currentFeeds = feeds.toList();
    try {
      final data = await (widget.calculate ?? FeedService.calculateFeed)(
          weight: c.estimatedWeight!,
          target: currentTarget,
          availableFeeds: currentFeeds);
      final plan = FeedPlan.fromApi(
          cattle: c,
          target: currentTarget,
          condition: currentCondition,
          feeds: currentFeeds,
          data: data);
      if (!mounted) return;
      final latest = FarmStore.instance.byId(c.id);
      if (latest == null || !plan.matches(latest))
        throw StateError(
            'Data sapi berubah selama perhitungan. Silakan hitung ulang.');
      final done = await Navigator.push<bool>(context,
          MaterialPageRoute(builder: (_) => FeedResultScreen(plan: plan)));
      if (done == true && mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() => error = e
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('FormatException: ', '')
            .replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmStore.instance,
      builder: (context, _) {
        final store = FarmStore.instance;
        final c = selected == null ? null : store.byId(selected!);
        return FarmPage(
            title: 'Racik rencana pakan',
            subtitle: 'Bobot terbaru. Bahan yang tersedia. Satu rencana.',
            eyebrow: '01 / 02 · INPUT KEBUTUHAN',
            back: true,
            children: [
              if (store.cattle.isEmpty)
                EmptyPanel(
                    title: 'Belum ada sapi',
                    message:
                        'Tambahkan sapi agar rekomendasi terhubung dengan profil dan bobotnya.',
                    action: FilledButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => const AddCattleScreen())),
                        child: const Text('Tambah sapi')))
              else ...[
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('PILIH SAPI',
                          style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: store.byId(selected ?? '') == null
                              ? null
                              : selected,
                          decoration: const InputDecoration(
                              labelText: 'Sapi yang akan dihitung'),
                          items: store.cattle
                              .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.nameOrId,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: busy
                              ? null
                              : (v) => setState(() {
                                    selected = v;
                                    error = null;
                                    final prior =
                                        v == null ? null : store.latestPlan(v);
                                    target = prior?.target ?? 'pemeliharaan';
                                    condition =
                                        prior?.bodyCondition ?? 'Tidak tahu';
                                    feeds = prior?.availableFeeds.toSet() ??
                                        {'rumput'};
                                  })),
                      if (c != null) ...[
                        const SizedBox(height: 18),
                        Row(children: [
                          CattleAvatar(cattle: c, size: 48),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    c.estimatedWeight == null
                                        ? 'Bobot belum tercatat'
                                        : '${kgLabel(c.estimatedWeight!)} kg',
                                    style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -.8)),
                                Text('${c.ageMonths} bulan · ${c.gender}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary))
                              ])),
                          TextButton(
                              onPressed: busy
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (_) =>
                                              CattleProfileScreen(cattle: c))),
                              child: Text(c.estimatedWeight == null
                                  ? 'Catat bobot'
                                  : 'Perbarui'))
                        ]),
                        if (c.history.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                  'Bobot terakhir ${dateLabel(c.history.last.date)}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)))
                      ]
                    ])),
                if (c != null && store.needsCheck(c))
                  const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: InfoBanner(
                          'Bobot belum dicatat atau sudah waktunya dicek. Gunakan bobot terbaru agar takaran lebih sesuai.',
                          warning: true)),
                const SectionHeading('Apa target pemeliharaannya?'),
                ...targetLabels.entries.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Material(
                        color: target == t.key
                            ? AppColors.primarySoft
                            : Colors.white,
                        borderRadius: BorderRadius.circular(19),
                        child: InkWell(
                            borderRadius: BorderRadius.circular(19),
                            onTap: busy
                                ? null
                                : () => setState(() => target = t.key),
                            child: Padding(
                                padding: const EdgeInsets.all(17),
                                child: Row(children: [
                                  Icon(
                                      target == t.key
                                          ? CupertinoIcons
                                              .check_mark_circled_solid
                                          : CupertinoIcons.circle,
                                      color: target == t.key
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      size: 22),
                                  const SizedBox(width: 13),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(t.value,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14)),
                                        const SizedBox(height: 4),
                                        Text(
                                            {
                                              'pemeliharaan':
                                                  'Menjaga kebutuhan harian sapi',
                                              'pertumbuhan':
                                                  'Mendukung fase tumbuh',
                                              'penggemukan':
                                                  'Mendukung penambahan bobot'
                                            }[t.key]!,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary))
                                      ]))
                                ])))))),
                const SectionHeading('Bahan yang tersedia'),
                const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                        'Pilih satu atau lebih. Takaran dihitung dari bahan pilihanmu.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary))),
                Panel(
                    padding: 8,
                    child: Column(
                        children: feedLabels.entries
                            .map((f) => SwitchListTile.adaptive(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                activeColor: AppColors.primary,
                                title: Text(f.value,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                subtitle: Text(
                                    {
                                      'rumput': 'Hijauan segar',
                                      'jerami': 'Serat dari jerami padi',
                                      'dedak': 'Bahan tambahan dedak padi'
                                    }[f.key]!,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary)),
                                value: feeds.contains(f.key),
                                onChanged: busy
                                    ? null
                                    : (v) => setState(() {
                                          if (v) {
                                            feeds.add(f.key);
                                          } else {
                                            feeds.remove(f.key);
                                          }
                                        })))
                            .toList())),
                const SectionHeading('Kondisi tubuh'),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Kurus', 'Sedang', 'Gemuk', 'Tidak tahu']
                        .map((v) => ChoiceChip(
                            label: Text(v),
                            selected: condition == v,
                            onSelected: busy
                                ? null
                                : (_) => setState(() => condition = v)))
                        .toList()),
                const SizedBox(height: 12),
                const Text(
                    'Umur dan kondisi tubuh dicatat sebagai konteks. Saat ini keduanya belum mengubah takaran otomatis.',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.6)),
                const SizedBox(height: 22),
                const InfoBanner(
                    'Untuk sapi potong yang tidak bunting dan tidak menyusui. Takaran dihitung oleh layanan pakan dari bobot, target, dan pilihan bahan.'),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: InfoBanner(error!, warning: true)),
                const SizedBox(height: 20),
                FilledButton.icon(
                    onPressed:
                        busy || c?.estimatedWeight == null ? null : calculate,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome_outlined, size: 20),
                    label: Text(busy
                        ? 'Menghitung kebutuhan…'
                        : 'Lihat rekomendasi pakan')),
              ]
            ]);
      });
}
