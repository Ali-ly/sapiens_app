import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/constants/app_colors.dart';
import '../../state/farm_store.dart';
import '../../widgets/farm_ui.dart';
import 'add_cattle_screen.dart';

class CattleListScreen extends StatefulWidget {
  const CattleListScreen({
    super.key,
    this.initialFilter = 'Semua',
    this.back = false,
  });
  final String initialFilter;
  final bool back;
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
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: FarmStore.instance,
        builder: (context, _) {
          final store = FarmStore.instance;
          final list = store.cattle
              .where(
                (c) =>
                    c.nameOrId.toLowerCase().contains(query.toLowerCase()) &&
                    (filter == 'Semua' ||
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
                '${store.cattle.length} sapi · satu tempat untuk semua catatan',
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
                  'Pakan belum siap'
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
                      child: Text('${list.length} sapi ditemukan',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary))),
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
              const SizedBox(height: 8),
              if (list.isEmpty)
                EmptyPanel(
                  title: store.cattle.isEmpty
                      ? 'Daftarkan sapi pertamamu'
                      : 'Sapi tidak ditemukan',
                  message: store.cattle.isEmpty
                      ? 'Mulai dengan identitas sapi dan bobot awal bila tersedia.'
                      : 'Coba kata kunci atau filter yang berbeda.',
                  action: store.cattle.isEmpty
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
                          onPressed: () => setState(() {
                            filter = 'Semua';
                            query = '';
                            search.clear();
                          }),
                          child: const Text('Reset filter'),
                        ),
                ),
              ...list.map((c) => CattleTile(cattle: c)),
            ],
          );
        },
      );
}
