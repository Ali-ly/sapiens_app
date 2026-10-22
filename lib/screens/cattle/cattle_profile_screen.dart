import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/cattle_draft.dart';
import '../../models/feed_plan.dart';
import '../../state/farm_store.dart';
import '../../widgets/farm_ui.dart';
import '../feed/feed_calculator_screen.dart';
import '../feed/feed_result_screen.dart';
import 'add_cattle_screen.dart';
import 'cattle_photo_screen.dart';

class CattleProfileScreen extends StatefulWidget {
  const CattleProfileScreen({super.key, required this.cattle});
  final CattleDraft cattle;
  @override
  State<CattleProfileScreen> createState() => _CattleProfileScreenState();
}

class _CattleProfileScreenState extends State<CattleProfileScreen> {
  int section = 0;
  Future<void> manual(BuildContext context, CattleDraft c) async {
    final done = await showDialog<bool>(
        context: context, builder: (_) => _WeightEntryDialog(cattle: c));
    if (done == true && context.mounted) {
      setState(() => section = 2);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Bobot tersimpan. Hitung ulang pakan dengan bobot terbaru.')));
    }
  }

  Future<void> photo(BuildContext context, CattleDraft c) async {
    await Navigator.push<CattleDraft>(
        context,
        MaterialPageRoute(
            builder: (_) => CattlePhotoScreen(draft: c, isRecheck: true)));
    if (mounted) setState(() => section = 2);
  }

  Future<void> remove(BuildContext context, CattleDraft c) async {
    final yes = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
                title: const Text('Hapus sapi ini?'),
                content: Text(
                    'Profil ${c.nameOrId}, riwayat bobot, foto, dan rencana pakannya akan dihapus dari perangkat ini.'),
                actions: [
                  CupertinoDialogAction(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal')),
                  CupertinoDialogAction(
                      isDestructiveAction: true,
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Hapus'))
                ]));
    if (yes == true) {
      try {
        await FarmStore.instance.remove(c.id);
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmStore.instance,
      builder: (context, _) {
        final store = FarmStore.instance;
        final c = store.byId(widget.cattle.id) ?? widget.cattle;
        final plan = store.latestPlan(c.id);
        final active = store.planReady(c);
        final history = store.feedPlans
            .where((p) => p.cattleId == c.id)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final delta = c.history.length < 2
            ? null
            : c.history.last.weightKg - c.history.first.weightKg;
        return FarmPage(
            title: c.nameOrId,
            subtitle: 'Setiap catatan membantu menentukan pakan berikutnya.',
            eyebrow: 'PROFIL TERNAK',
            back: true,
            action: IconButton(
                tooltip: 'Edit profil sapi',
                style: IconButton.styleFrom(backgroundColor: Colors.white),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => AddCattleScreen(cattle: c))),
                icon: const Icon(CupertinoIcons.pencil, size: 20)),
            children: [
              Panel(
                  child: Row(children: [
                CattleAvatar(cattle: c, size: 76),
                const SizedBox(width: 18),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${c.gender} · ${c.ageMonths} bulan',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 11),
                      StatusPill(
                          store.needsCheck(c)
                              ? 'Waktunya cek bobot'
                              : 'Bobot terkini',
                          warning: store.needsCheck(c))
                    ]))
              ])),
              const SizedBox(height: 14),
              Panel(
                  color: AppColors.primaryDark,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('BOBOT TERAKHIR',
                            style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.5,
                                color: Color(0xFFBBC9B7))),
                        const SizedBox(height: 12),
                        Text(
                            c.estimatedWeight == null
                                ? 'Belum tercatat'
                                : '${kgLabel(c.estimatedWeight!)} kg',
                            style: TextStyle(
                                fontSize: c.estimatedWeight == null ? 28 : 48,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -1.8,
                                color: Colors.white)),
                        const SizedBox(height: 7),
                        Text(
                            c.history.isEmpty
                                ? 'Catat bobot pertama untuk menghitung pakan.'
                                : '${dateLabel(c.history.last.date)} · ${c.history.last.sourceLabel}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFFBBC9B7))),
                        if (delta != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: StatusPill(
                                  '${delta >= 0 ? '+' : ''}${kgLabel(delta)} kg sejak catatan pertama',
                                  dark: true))
                      ])),
              const SizedBox(height: 16),
              FilledButton.icon(
                  onPressed: () => photo(context, c),
                  icon: const Icon(CupertinoIcons.camera, size: 20),
                  label: const Text('Estimasi bobot dari foto')),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                  onPressed: () => manual(context, c),
                  icon: const Icon(CupertinoIcons.gauge, size: 20),
                  label: const Text('Catat bobot manual')),
              const SizedBox(height: 24),
              CupertinoSlidingSegmentedControl<int>(
                  groupValue: section,
                  backgroundColor: AppColors.divider,
                  children: const {
                    0: Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child:
                            Text('Ringkasan', style: TextStyle(fontSize: 12))),
                    1: Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text('Bobot', style: TextStyle(fontSize: 12))),
                    2: Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text('Pakan', style: TextStyle(fontSize: 12)))
                  },
                  onValueChanged: (v) {
                    if (v != null) setState(() => section = v);
                  }),
              if (section == 0) ...[
                const SectionHeading('Perkembangan bobot'),
                if (c.history.length < 2)
                  const Panel(
                      child: Text(
                          'Grafik akan muncul setelah ada minimal dua catatan bobot.',
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: AppColors.textSecondary)))
                else
                  Panel(
                      child: Column(children: [
                    Semantics(
                        label:
                            'Grafik ${c.history.length} catatan bobot, dari ${kgLabel(c.history.first.weightKg)} ke ${kgLabel(c.history.last.weightKg)} kilogram',
                        child: SizedBox(
                            height: 150,
                            width: double.infinity,
                            child:
                                CustomPaint(painter: WeightChart(c.history)))),
                    const SizedBox(height: 14),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(dateLabel(c.history.first.date),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary)),
                          Text(dateLabel(c.history.last.date),
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textSecondary))
                        ])
                  ])),
                const SectionHeading('Rencana pakan'),
                feedPanel(context, c, plan, active),
                const SectionHeading('Catatan ternak'),
                Panel(
                    child: Text(
                        c.notes.isEmpty
                            ? 'Belum ada catatan tambahan.'
                            : c.notes,
                        style: const TextStyle(fontSize: 13, height: 1.7))),
                if (c.images.isNotEmpty) ...[
                  const SectionHeading('Galeri foto'),
                  SizedBox(
                      height: 150,
                      child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: c.images.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(21),
                              child: Image.memory(c.images[i].bytes,
                                  width: 170,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                      width: 170,
                                      child: Center(
                                          child:
                                              Icon(CupertinoIcons.photo)))))))
                ],
              ] else if (section == 1) ...[
                SectionHeading('Riwayat bobot',
                    action: StatusPill('${c.history.length} catatan')),
                if (c.history.isEmpty)
                  const EmptyPanel(
                      title: 'Belum ada catatan',
                      message:
                          'Ambil foto untuk estimasi bobot atau catat hasil timbangan.')
                else
                  ...c.history.reversed.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Panel(
                          padding: 17,
                          child: Row(children: [
                            Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(13)),
                                child: Icon(
                                    r.source == 'ai'
                                        ? CupertinoIcons.camera
                                        : CupertinoIcons.gauge,
                                    color: AppColors.primary,
                                    size: 21)),
                            const SizedBox(width: 13),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(dateLabel(r.date),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 5),
                                  Text(r.sourceLabel,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary))
                                ])),
                            Text('${kgLabel(r.weightKg)} kg',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -.5))
                          ])))),
              ] else ...[
                const SectionHeading('Pakan untuk sapi ini'),
                feedPanel(context, c, plan, active),
                if (history.isNotEmpty) ...[
                  const SectionHeading('Riwayat rencana'),
                  ...history.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Panel(
                          padding: 6,
                          child: ListTile(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) => FeedResultScreen(
                                          plan: p, saved: true))),
                              leading: const Icon(Icons.grass_rounded,
                                  color: AppColors.primary),
                              title: Text(
                                  '${kgLabel(p.totalFreshKg)} kg / hari',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  '${dateLabel(p.createdAt)} · bobot ${kgLabel(p.weightKg)} kg',
                                  style: const TextStyle(fontSize: 10)),
                              trailing:
                                  const Icon(CupertinoIcons.chevron_right, size: 14)))))
                ]
              ],
              const SizedBox(height: 26),
              TextButton.icon(
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () => remove(context, c),
                  icon: const Icon(CupertinoIcons.trash, size: 17),
                  label: const Text('Hapus sapi')),
            ]);
      });
  Widget feedPanel(
          BuildContext context, CattleDraft c, FeedPlan? plan, bool active) =>
      Panel(
          color: AppColors.primarySoft,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.grass_rounded,
                  color: AppColors.primary, size: 26),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        plan == null
                            ? 'Dari bobot ke pakan'
                            : '${kgLabel(plan.totalFreshKg)} kg / hari',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.7)),
                    const SizedBox(height: 5),
                    Text(
                        plan == null
                            ? 'Hitung kebutuhan sesuai targetmu.'
                            : active
                                ? 'Rencana terkini siap digunakan.'
                                : 'Perbarui rencana dengan data terbaru.',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary))
                  ]))
            ]),
            const SizedBox(height: 18),
            FilledButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => FeedCalculatorScreen(cattleId: c.id))),
                icon: const Icon(CupertinoIcons.arrow_right, size: 18),
                label: Text(plan == null
                    ? 'Hitung kebutuhan pakan'
                    : 'Hitung ulang pakan')),
            if (plan != null)
              TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              FeedResultScreen(plan: plan, saved: true))),
                  child: const Text('Lihat rincian rencana'))
          ]));
}

class WeightChart extends CustomPainter {
  WeightChart(this.records);
  final List<WeightRecord> records;
  @override
  void paint(Canvas canvas, Size size) {
    final values = records.map((r) => r.weightKg).toList();
    final min = values.reduce((a, b) => a < b ? a : b) - 10;
    final max = values.reduce((a, b) => a > b ? a : b) + 10;
    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final y = 10 + (size.height - 20) * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final first = records.first.date.millisecondsSinceEpoch;
    final span = records.last.date.millisecondsSinceEpoch - first;
    final points = List.generate(
      values.length,
      (i) => Offset(
        span == 0
            ? size.width * i / (values.length - 1)
            : size.width *
                (records[i].date.millisecondsSinceEpoch - first) /
                span,
        size.height - 10 - (values[i] - min) / (max - min) * (size.height - 20),
      ),
    );
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()..color = AppColors.primarySoft.withOpacity(.65),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 4, Paint()..color = AppColors.primary);
      if (i == 0 || i == points.length - 1) {
        final text = TextPainter(
          text: TextSpan(
            text: '${values[i].toStringAsFixed(0)} kg',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(
          canvas,
          Offset(
            (points[i].dx - text.width / 2)
                .clamp(0, size.width - text.width)
                .toDouble(),
            (points[i].dy - 22).clamp(0, size.height - text.height).toDouble(),
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant WeightChart oldDelegate) =>
      oldDelegate.records != records;
}

class _WeightEntryDialog extends StatefulWidget {
  const _WeightEntryDialog({required this.cattle});
  final CattleDraft cattle;
  @override
  State<_WeightEntryDialog> createState() => _WeightEntryDialogState();
}

class _WeightEntryDialogState extends State<_WeightEntryDialog> {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  bool saving = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final c = FarmStore.instance.byId(widget.cattle.id) ?? widget.cattle;
      final n = double.parse(controller.text.trim().replaceAll(',', '.'));
      await FarmStore.instance.save(c.copyWith(
          estimatedWeight: n,
          clearPrediction: true,
          latestCheckImages: const [],
          validImages: 0,
          rejectedImages: 0,
          history: [
            ...c.history,
            WeightRecord(weightKg: n, date: DateTime.now(), source: 'manual')
          ]));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: const Text('Catat bobot'),
        content: Form(
            key: form,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Masukkan hasil timbangan hari ini.'),
                  const SizedBox(height: 16),
                  TextFormField(
                      autofocus: true,
                      controller: controller,
                      enabled: !saving,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Bobot (kg)'),
                      validator: (v) {
                        final n = double.tryParse(
                            (v ?? '').trim().replaceAll(',', '.'));
                        return n == null || !n.isFinite || n < 1 || n > 2000
                            ? 'Masukkan bobot 1–2.000 kg.'
                            : null;
                      })
                ])),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Batal')),
          FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Menyimpan…' : 'Simpan bobot'))
        ],
      ));
}
