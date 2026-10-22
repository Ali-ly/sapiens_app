import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../state/farm_store.dart';
import '../../widgets/farm_ui.dart';
import '../cattle/add_cattle_screen.dart';
import '../cattle/cattle_list_screen.dart';
import '../cattle/cattle_profile_screen.dart';
import '../feed/feed_calculator_screen.dart';
import '../feed/feed_shopping_screen.dart';
import '../profile/farm_settings_screen.dart';
import 'insights_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onSeeAll, this.onFeed});
  final VoidCallback? onSeeAll, onFeed;
  void checkWeight(BuildContext context) {
    final cattle = FarmStore.instance.cattle;
    if (cattle.isEmpty) {
      Navigator.push(context,
          MaterialPageRoute<void>(builder: (_) => const AddCattleScreen()));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => SafeArea(
          child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
              padding: EdgeInsets.fromLTRB(22, 6, 22, 18),
              child: Text('Sapi mana yang ingin dicek?',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600))),
          Flexible(
              child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: cattle.length,
                  itemBuilder: (_, i) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 5),
                        leading: CattleAvatar(cattle: cattle[i], size: 44),
                        title: Text(cattle[i].nameOrId),
                        trailing:
                            const Icon(CupertinoIcons.chevron_right, size: 15),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      CattleProfileScreen(cattle: cattle[i])));
                        },
                      ))),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = FarmStore.instance;
    final due = store.cattle.where(store.needsCheck).toList();
    final ready = store.cattle.where(store.planReady).length;
    final total = store.dailyFeedTotals.values.fold(0.0, (a, b) => a + b);
    return FarmPage(
        title: store.farmer == 'Peternak'
            ? 'Selamat datang di SAPITA.'
            : 'Halo, ${store.farmer}.',
        subtitle: '${store.farm} · ${dateLabel(DateTime.now())}',
        action: IconButton(
            tooltip: 'Pengingat bobot',
            style: IconButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const CattleListScreen(
                        initialFilter: 'Perlu dicek', back: true))),
            icon: Badge(
                isLabelVisible: due.isNotEmpty,
                backgroundColor: AppColors.warning,
                label: Text('${due.length}'),
                child: const Icon(CupertinoIcons.bell, size: 21))),
        children: [
          if (store.error != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InfoBanner(store.error!, warning: true)),
          if (store.demo)
            const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: StatusPill('DATA CONTOH · untuk menjelajahi fitur')),
          ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Stack(children: [
                Positioned.fill(
                    child: Container(
                        color: AppColors.primaryDark,
                        child: CustomPaint(painter: _MeadowLines()))),
                Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const StatusPill('PANTAU BOBOT, RENCANAKAN PAKAN',
                              dark: true),
                          const SizedBox(height: 24),
                          const Text('Dari bobot,\nke pakan tepat.',
                              style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -1.7,
                                  height: 1.1,
                                  color: Colors.white)),
                          const SizedBox(height: 14),
                          const SizedBox(
                              width: 250,
                              child: Text(
                                  'Kenali kebutuhan setiap sapi. Siapkan pakan dengan lebih terarah.',
                                  style: TextStyle(
                                      fontSize: 13,
                                      height: 1.65,
                                      color: Color(0xFFBBC9B7)))),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: AppColors.primaryDark),
                              onPressed: onFeed ??
                                  () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const FeedCalculatorScreen())),
                              icon: const Icon(Icons.grass_rounded, size: 20),
                              label: const Text('Rencanakan pakan'))
                        ]))
              ])),
          const SizedBox(height: 16),
          Row(children: [
            StatTile('${store.cattle.length}', 'Sapi terdaftar',
                CupertinoIcons.square_stack_3d_up),
            const SizedBox(width: 9),
            StatTile('$ready', 'Pakan siap', Icons.grass_rounded),
            const SizedBox(width: 9),
            StatTile('${due.length}', 'Perlu dicek', CupertinoIcons.clock,
                warning: true)
          ]),
          const SectionHeading('Mulai dari sini'),
          Row(children: [
            Expanded(
                child: _QuickAction(
                    icon: CupertinoIcons.camera,
                    label: 'Cek bobot',
                    subtitle: 'Foto atau timbangan',
                    onTap: () => checkWeight(context))),
            const SizedBox(width: 12),
            Expanded(
                child: _QuickAction(
                    icon: CupertinoIcons.add,
                    label: 'Tambah sapi',
                    subtitle: 'Daftarkan ternak baru',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => const AddCattleScreen()))))
          ]),
          if (store.cattle.isEmpty) ...[
            const SectionHeading('Siapkan peternakanmu'),
            Panel(
                padding: 8,
                child: ListTile(
                    leading: const Icon(CupertinoIcons.house,
                        color: AppColors.primary),
                    title: const Text('Atur nama & pengingat',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text(
                        'Personalisasikan SAPITA sebelum mencatat sapi.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    trailing:
                        const Icon(CupertinoIcons.chevron_right, size: 14),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => const FarmSettingsScreen())))),
            const SectionHeading('Kandang digitalmu dimulai di sini'),
            EmptyPanel(
                title: 'Belum ada sapi',
                message:
                    'Tambahkan sapi, catat bobot, lalu hitung kebutuhan pakannya. Atau jelajahi aplikasi dengan data contoh.',
                action: OutlinedButton(
                    onPressed: () async {
                      try {
                        await store.addExamples();
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                    },
                    child: const Text('Coba dengan data contoh')))
          ] else ...[
            SectionHeading('Pakan hari ini',
                action: TextButton(
                    onPressed: onFeed, child: const Text('Lihat semua'))),
            Panel(
                color: AppColors.primarySoft,
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.65),
                          borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.grass_rounded,
                          color: AppColors.primary, size: 26)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            ready == 0
                                ? 'Belum ada rencana'
                                : '${kgLabel(total)} kg / hari',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -.8)),
                        const SizedBox(height: 4),
                        Text(
                            ready == 0
                                ? 'Hitung kebutuhan pakan sapimu.'
                                : 'Pakan segar untuk $ready sapi',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary))
                      ])),
                  IconButton(
                      tooltip: 'Persiapan pakan',
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const FeedShoppingScreen())),
                      icon: const Icon(CupertinoIcons.arrow_up_right, size: 19))
                ])),
            if (ready < store.cattle.length)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: InfoBanner(
                      '${store.cattle.length - ready} sapi belum memiliki rencana pakan terkini. Buka tab Pakan untuk melengkapinya.',
                      warning: true)),
            SectionHeading('Sapi saya',
                action: TextButton(
                    onPressed: onSeeAll, child: const Text('Lihat semua'))),
            ...store.cattle.take(3).map((c) => CattleTile(cattle: c)),
            if (due.isNotEmpty) ...[
              SectionHeading('Waktunya cek bobot',
                  action: StatusPill('${due.length} sapi', warning: true)),
              ...due.take(2).map((c) => CattleTile(cattle: c))
            ],
            const SectionHeading('Perkembangan kandang'),
            Panel(
                padding: 8,
                child: ListTile(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => const InsightsScreen())),
                    leading: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(13)),
                        child: const Icon(CupertinoIcons.chart_bar,
                            color: AppColors.primary)),
                    title: const Text('Ringkasan & aktivitas',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${store.checksThisWeek} catatan bobot dalam 7 hari',
                        style: const TextStyle(fontSize: 11)),
                    trailing:
                        const Icon(CupertinoIcons.chevron_right, size: 14))),
          ]
        ]);
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String label, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: AppColors.primary, size: 25),
                    const SizedBox(height: 19),
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            letterSpacing: -.3)),
                    const SizedBox(height: 5),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary))
                  ]))));
}

class _MeadowLines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = const Color(0xFF3E513C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 0; i < 8; i++) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(s.width + 30, s.height * .5),
              width: 110.0 + i * 34,
              height: 110.0 + i * 50),
          paint);
    }
    canvas.drawCircle(Offset(s.width - 38, 55), 7,
        Paint()..color = AppColors.accent.withOpacity(.65));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
