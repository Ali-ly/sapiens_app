import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../application/providers.dart';
import '../../domain/value.dart';
import '../../ui/avatar.dart';
import '../../ui/components.dart';
import '../care/care_section.dart';
import '../feed/feed_section.dart';
import '../milk/milk_section.dart';
import '../weight/weight_section.dart';
import 'edit_identity_page.dart';
import 'overviews.dart';

enum ProfileSection { summary, weight, milk, feed, care }

extension ProfileSectionLabel on ProfileSection {
  String get label => const [
        'Ringkasan',
        'Bobot',
        'Produksi Susu',
        'Pakan',
        'Perawatan'
      ][index];
}

class CattleProfilePage extends ConsumerStatefulWidget {
  const CattleProfilePage(
      {super.key,
      required this.cattleId,
      this.initial = ProfileSection.summary});
  final String cattleId;
  final ProfileSection initial;
  @override
  ConsumerState<CattleProfilePage> createState() => _CattleProfilePageState();
}

class _CattleProfilePageState extends ConsumerState<CattleProfilePage> {
  late ProfileSection section;
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    section = widget.initial;
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void go(ProfileSection value) {
    setState(() => section = value);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(farmProvider).requireValue,
        c = data.find(widget.cattleId);
    if (c == null) {
      return const PageFrame(
          title: 'Profil Sapi tidak tersedia',
          subtitle:
              'Data mungkin telah dipulihkan atau mode peternakan diganti.',
          children: []);
    }
    final mode = data.account!.mode, now = ref.watch(clockProvider)();
    final maleDairy = mode == FarmMode.dairy && c.sex == Sex.male;
    final visibleSection =
        section == ProfileSection.milk && (mode != FarmMode.dairy || maleDairy)
            ? ProfileSection.summary
            : section;
    final sections = ProfileSection.values
        .where((s) => s != ProfileSection.milk || mode == FarmMode.dairy)
        .toList();
    final Widget body = switch (visibleSection) {
      ProfileSection.summary => mode == FarmMode.beef
          ? BeefOverview(cattle: c, now: now, go: go)
          : DairyOverview(cattle: c, now: now, go: go),
      ProfileSection.weight => WeightSection(cattle: c),
      ProfileSection.milk => MilkSection(cattle: c),
      ProfileSection.feed => FeedSection(cattle: c, mode: mode),
      ProfileSection.care => CareSection(cattle: c, mode: mode),
    };
    return Scaffold(
        appBar: AppBar(title: const Text('Profil Sapi'), actions: [
          IconButton(
              tooltip: 'Edit Profil Sapi',
              onPressed: c.active
                  ? () => openPage(context, EditIdentityPage(cattle: c))
                  : null,
              icon: const Icon(Icons.edit_outlined)),
          PopupMenuButton<String>(
              onSelected: (value) async {
                final yes = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                            title: Text(c.active
                                ? 'Arsipkan sapi?'
                                : 'Aktifkan kembali?'),
                            content: Text(c.active
                                ? 'Histori tetap tersimpan. Sapi dikeluarkan dari daftar aktif.'
                                : 'Histori tetap dipertahankan saat sapi diaktifkan kembali.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Batal')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child:
                                      Text(c.active ? 'Arsipkan' : 'Aktifkan'))
                            ]));
                if (yes == true) {
                  try {
                    await ref
                        .read(farmProvider.notifier)
                        .archive(c.id, c.active);
                  } catch (e) {
                    if (context.mounted) toast(context, errorText(e));
                  }
                }
              },
              itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'archive',
                        child: Text(
                            c.active ? 'Arsipkan sapi' : 'Aktifkan kembali'))
                  ])
        ]),
        body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                          child: Row(children: [
                            CowAvatar(cattle: c, size: 74),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(c.name,
                                      style: const TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -.6)),
                                  if (c.userId.isNotEmpty)
                                    Text('ID ${c.userId}',
                                        style: const TextStyle(
                                            color: Palette.muted)),
                                  Text(
                                      '${c.sex.label} · ${c.ageMonths} bulan · ${number(c.latestWeight.kg)} kg',
                                      style: const TextStyle(
                                          color: Palette.muted)),
                                  if (!c.active)
                                    const Tag('Diarsipkan', warning: true)
                                ]))
                          ])),
                      SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(children: [
                            for (final s in sections)
                              Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Tooltip(
                                      message: s == ProfileSection.milk &&
                                              maleDairy
                                          ? 'Produksi susu tidak aktif untuk jantan.'
                                          : s.label,
                                      child: ChoiceChip(
                                          key: ValueKey('profile-${s.name}'),
                                          label: Text(s.label),
                                          selected: visibleSection == s,
                                          onSelected:
                                              s == ProfileSection.milk &&
                                                      maleDairy
                                                  ? null
                                                  : (_) => go(s))))
                          ])),
                      const SizedBox(height: 12),
                      Expanded(
                          child: SingleChildScrollView(
                              key: ValueKey(
                                  'profile-body-${visibleSection.name}'),
                              controller: scroll,
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                              child: body)),
                    ]))));
  }
}
