import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/cattle.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../groups/group_list_screen.dart';
import 'add_cattle_screen.dart';
import 'cattle_profile_screen.dart';

class CattleListScreen extends StatefulWidget {
  const CattleListScreen({
    super.key,
    this.initialFilter = 'Semua',
    this.back = false,
    this.filterRequest = 0,
  });
  final String initialFilter;
  final bool back;
  final int filterRequest;
  @override
  State<CattleListScreen> createState() => _CattleListScreenState();
}

class _CattleListScreenState extends State<CattleListScreen> {
  String query = '';
  late String filter;
  String sort = 'Nama';
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    filter = widget.initialFilter;
  }

  @override
  void didUpdateWidget(covariant CattleListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterRequest != widget.filterRequest) {
      filter = widget.initialFilter;
      query = '';
      search.clear();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: FarmScope.read(context),
        builder: (context, _) {
          final store = FarmScope.read(context);
          final list = ((filter == 'Arsip' || filter == 'Nonaktif')
                  ? store.inactiveCattle
                  : store.cattle)
              .where(
                (c) =>
                    c.nameOrId.toLowerCase().contains(query.toLowerCase()) &&
                    (filter == 'Semua' ||
                        filter == 'Arsip' &&
                            c.status == CattleStatus.archived ||
                        filter == 'Nonaktif' ||
                        filter == 'Beef' &&
                            c.productionCategory == ProductionCategory.beef ||
                        filter == 'Dairy' &&
                            c.productionCategory == ProductionCategory.dairy ||
                        filter == 'Belum diklasifikasi' &&
                            c.productionCategory == null ||
                        filter == 'Perlu dicek' && store.needsCheck(c) ||
                        c.gender == filter ||
                        filter == 'Pakan belum siap' && !store.planReady(c)),
              )
              .toList()
            ..sort(
              (a, b) => sort == 'Bobot tertinggi'
                  ? (b.estimatedWeight ?? 0).compareTo(a.estimatedWeight ?? 0)
                  : a.nameOrId.compareTo(b.nameOrId),
            );
          return FarmPage(
            title: 'Kenali setiap sapimu.',
            eyebrow: 'KANDANG DIGITAL',
            subtitle:
                '${store.cattle.length} aktif · ${store.inactiveCattle.length} nonaktif',
            back: widget.back,
            action: IconButton.filled(
              tooltip: 'Tambah sapi',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const AddCattleScreen()),
              ),
              icon: const Icon(Icons.add),
            ),
            children: [
              TextField(
                controller: search,
                onChanged: (v) => setState(() => query = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(CupertinoIcons.search),
                  hintText: 'Cari nama atau ID sapi',
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 4,
                children: [
                  'Semua',
                  'Jantan',
                  'Betina',
                  'Perlu dicek',
                  'Pakan belum siap',
                  'Nonaktif',
                  'Arsip',
                  if (store.productionSystems != FarmProductionSystems.dairy)
                    'Beef',
                  if (store.productionSystems != FarmProductionSystems.beef)
                    'Dairy',
                  'Belum diklasifikasi'
                ]
                    .map(
                      (f) => ChoiceChip(
                        label: Text(f),
                        selected: filter == f,
                        onSelected: (_) => setState(() => filter = f),
                      ),
                    )
                    .toList(),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${list.length} sapi ditemukan',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: sort,
                    underline: const SizedBox(),
                    items: ['Nama', 'Bobot tertinggi']
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child:
                                Text(s, style: const TextStyle(fontSize: 12)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => sort = v!),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const GroupListScreen())),
                  icon: const Icon(Icons.grid_view_rounded, size: 18),
                  label: const Text('Kelompok/kandang (opsional)'),
                ),
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                EmptyPanel(
                  title: store.allCattle.isEmpty
                      ? 'Daftarkan sapi pertamamu'
                      : 'Sapi tidak ditemukan',
                  message: store.allCattle.isEmpty
                      ? 'Tambah identitas sapi, lalu catat bobot dan hitung pakannya. Tidak perlu membuat kandang.'
                      : 'Coba kata kunci atau filter yang berbeda.',
                  action: store.allCattle.isEmpty
                      ? FilledButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const AddCattleScreen(),
                            ),
                          ),
                          child: const Text('Tambah sapi'),
                        )
                      : TextButton(
                          onPressed: () => setState(
                            () {
                              filter = 'Semua';
                              query = '';
                              search.clear();
                            },
                          ),
                          child: const Text('Reset filter'),
                        ),
                ),
              ...list.map(
                (c) => CattleTile(
                  cattle: c,
                  feedReady: store.planReady(c),
                  needsWeightCheck: store.needsCheck(c),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => CattleProfileScreen(cattle: c)),
                  ),
                ),
              ),
            ],
          );
        },
      );
}
