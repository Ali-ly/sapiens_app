import 'package:flutter/material.dart';

import '../../models/cattle.dart';
import '../../models/dairy/dairy_metrics.dart';
import '../../models/feed_api_v2.dart';
import '../../services/cattle_nutrition_context.dart';
import '../../services/feed_service.dart';
import '../../state/farm_scope.dart';
import '../../state/farm_store.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/livestock_labels.dart';
import '../cattle/add_cattle_screen.dart';
import '../cattle/cattle_list_screen.dart';
import '../cattle/cattle_profile_screen.dart';
import '../cattle/widgets/weight_entry_dialog.dart';
import 'feed_result_screen.dart';

typedef FeedCatalogLoader = Future<FeedCatalogResponse> Function(
    {required ProductionCategory productionCategory});
typedef NutritionEvaluation = Future<NutritionResponse> Function(
    {required NutritionRequest request});

class FeedCalculatorScreen extends StatefulWidget {
  const FeedCalculatorScreen(
      {super.key,
      this.cattleId,
      this.productionCategory,
      this.onChangeDomain,
      this.loadFeeds,
      this.evaluate,
      this.now});
  final String? cattleId;
  final ProductionCategory? productionCategory;
  final VoidCallback? onChangeDomain;
  final FeedCatalogLoader? loadFeeds;
  final NutritionEvaluation? evaluate;
  final DateTime Function()? now;
  @override
  State<FeedCalculatorScreen> createState() => _FeedCalculatorScreenState();
}

class _FeedCalculatorScreenState extends State<FeedCalculatorScreen> {
  final form = GlobalKey<FormState>();
  final quantities = <String, TextEditingController>{};
  final chosen = <String>{};
  final targetAdg = TextEditingController();
  late final FarmStore store;
  String? selected, error, catalogError;
  FeedCatalogResponse? catalog;
  bool loading = false, busy = false;
  int loadGeneration = 0, submitGeneration = 0;
  ProductionCategory? observedCategory;
  bool? observedActive;

  DateTime get now => (widget.now ?? DateTime.now)();
  Cattle? get cattle => selected == null ? null : store.byId(selected!);
  List<Cattle> get selectableCattle => store.cattle
      .where((c) =>
          widget.productionCategory == null ||
          c.productionCategory == widget.productionCategory)
      .toList();
  String get domainLabel =>
      widget.productionCategory == ProductionCategory.dairy
          ? 'Sapi Perah'
          : 'Sapi Pedaging';

  Future<void> changeDomain() async {
    final change = widget.onChangeDomain;
    if (change == null || busy) return;
    if (targetAdg.text.trim().isNotEmpty || chosen.isNotEmpty) {
      final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Ganti jenis sapi?'),
                content: const Text(
                    'Pilihan sapi dan input pakan di halaman ini akan dibersihkan. Catatan yang sudah tersimpan tetap aman.'),
                actions: [
                  TextButton(
                      key: const ValueKey('feed-domain-change-cancel'),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Tetap di sini')),
                  FilledButton(
                      key: const ValueKey('feed-domain-change-confirm'),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Ganti jenis sapi')),
                ],
              ));
      if (discard != true || !mounted) return;
    }
    change();
  }

  @override
  void initState() {
    super.initState();
    store = FarmScope.read(context);
    selected = widget.cattleId;
    observedCategory = cattle?.productionCategory;
    observedActive = cattle?.isActive;
    store.addListener(twinChanged);
    loadCatalog();
  }

  void twinChanged() {
    if (!mounted) return;
    // Any Twin edit invalidates an in-flight evaluation/acknowledgement.
    submitGeneration++;
    setState(() {
      error = null;
    });
    if (observedCategory != cattle?.productionCategory ||
        observedActive != cattle?.isActive) {
      observedCategory = cattle?.productionCategory;
      observedActive = cattle?.isActive;
      if (widget.productionCategory != null &&
          cattle?.productionCategory != widget.productionCategory) {
        selected = null;
      }
      loadCatalog();
    }
  }

  void resetIngredients() {
    targetAdg.clear();
    chosen.clear();
    for (final controller in quantities.values) {
      controller.dispose();
    }
    quantities.clear();
  }

  Future<void> loadCatalog() async {
    final generation = ++loadGeneration;
    final c = cattle;
    final category = c?.productionCategory;
    resetIngredients();
    setState(() {
      catalog = null;
      catalogError = null;
      error = null;
      loading = c?.isActive == true &&
          category != null &&
          (widget.productionCategory == null ||
              category == widget.productionCategory);
    });
    if (!loading) return;
    try {
      final result = await (widget.loadFeeds ?? FeedService.fetchFeeds)(
          productionCategory: category!);
      if (!mounted || generation != loadGeneration || selected != c!.id) return;
      if (result.productionCategory != category ||
          result.feeds.map((f) => f.feedId).toSet().length !=
              result.feeds.length) {
        throw const FormatException(
            'Katalog bahan tidak sesuai atau ID bahan duplikat.');
      }
      for (final feed in result.feeds) {
        quantities[feed.feedId] = TextEditingController();
      }
      setState(() {
        catalog = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted || generation != loadGeneration) return;
      setState(() {
        catalogError = errorMessage(e);
        loading = false;
      });
    }
  }

  String? contextError(Cattle? c) {
    if (c == null) return 'Pilih sapi terlebih dahulu.';
    if (widget.productionCategory != null &&
        c.productionCategory != widget.productionCategory) {
      return 'Pilih $domainLabel yang sesuai dengan alur ini.';
    }
    try {
      CattleNutritionContext.fromTwin(c, now);
      return null;
    } catch (e) {
      return errorMessage(e);
    }
  }

  Future<void> evaluate() async {
    if (busy || loading || catalog == null) return;
    final c = cattle;
    final issue = contextError(c);
    if (issue != null) {
      setState(() => error = issue);
      return;
    }
    if (chosen.isEmpty) {
      setState(
          () => error = 'Pilih minimal satu bahan dan isi jumlah kg/hari.');
      return;
    }
    if (!form.currentState!.validate()) return;
    var context = CattleNutritionContext.fromTwin(c!, now);
    if (context.data['purpose'] == 'penggemukan') {
      context = NutritionCattleContext.beef(
          bodyWeightKg: context.bodyWeightKg,
          purpose: 'penggemukan',
          targetAdgKgDay:
              double.parse(targetAdg.text.trim().replaceAll(',', '.')));
    }
    final request = NutritionRequest(cattle: context, feedItems: [
      for (final feed in catalog!.feeds)
        if (chosen.contains(feed.feedId))
          NutritionFeedItem(
              feedId: feed.feedId,
              asFedKgDay: double.parse(
                  quantities[feed.feedId]!.text.trim().replaceAll(',', '.'))),
    ]);
    final generation = ++submitGeneration;
    FocusScope.of(this.context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await (widget.evaluate ??
          FeedService.calculateNutrition)(request: request);
      if (!mounted) return;
      if (generation != submitGeneration ||
          selected != c.id ||
          cattle == null ||
          !CattleNutritionContext.matchesTwin(context, cattle!, now)) {
        throw StateError(
            'Data sapi berubah selama evaluasi. Periksa lalu kirim ulang.');
      }
      if (response.productionCategory != null &&
          response.productionCategory != request.productionCategory) {
        throw const FormatException(
            'Kategori hasil nutrisi tidak sesuai input.');
      }
      final plan = store.createNutritionPlan(
          cattle: c, request: request, response: response);
      final done = await Navigator.push<bool>(
          this.context,
          MaterialPageRoute<bool>(
              builder: (_) => FeedResultScreen(plan: plan)));
      if (mounted &&
          (done == true || store.feedPlans.any((p) => p.id == plan.id))) {
        Navigator.pop(this.context, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    store.removeListener(twinChanged);
    loadGeneration++;
    submitGeneration++;
    resetIngredients();
    targetAdg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = cattle;
    final issue = contextError(c);
    return FarmPage(
      title: widget.productionCategory == null
          ? 'Evaluasi pakan individual'
          : 'Pakan $domainLabel',
      subtitle: 'Pilih sapi dan isi pakan yang diberikan setiap hari.',
      back: true,
      children: [
        if (widget.productionCategory != null) ...[
          Panel(
              key: const ValueKey('nutrition-domain-context'),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.productionCategory == ProductionCategory.beef
                        ? 'Konteks Pedaging · Beef'
                        : 'Konteks Perah · Dairy'),
                    const Text(
                        'Daftar sapi dan evaluasi pakan mengikuti konteks ini.'),
                    if (widget.onChangeDomain != null)
                      TextButton(
                          onPressed: busy ? null : changeDomain,
                          child: const Text('Ganti jenis sapi')),
                  ])),
          const SizedBox(height: 16),
          if (store.cattle.any((c) => c.productionCategory == null))
            TextButton.icon(
                onPressed: busy
                    ? null
                    : () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => const CattleListScreen(
                                initialFilter: 'Belum diklasifikasi',
                                back: true))),
                icon: const Icon(Icons.assignment_ind_outlined),
                label: const Text('Lengkapi kategori sapi lainnya')),
        ],
        if (selectableCattle.isEmpty)
          EmptyPanel(
              title: widget.productionCategory == null
                  ? 'Belum ada sapi aktif'
                  : 'Belum ada $domainLabel aktif',
              message:
                  'Tambahkan sapi atau lengkapi kategori pada profil ternak yang sudah ada.',
              action: FilledButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => AddCattleScreen(
                              initialCategory: widget.productionCategory))),
                  child: const Text('Tambah sapi'))),
        if (selectableCattle.isNotEmpty)
          DropdownButtonFormField<String>(
              key: const ValueKey('nutrition-cattle'),
              value: selectableCattle.any((a) => a.id == selected)
                  ? selected
                  : null,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Sapi yang akan dievaluasi'),
              items: [
                for (final a in selectableCattle)
                  DropdownMenuItem(
                      value: a.id,
                      child: Text(a.nameOrId, overflow: TextOverflow.ellipsis))
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      setState(() {
                        selected = value;
                        error = null;
                      });
                      observedCategory = cattle?.productionCategory;
                      observedActive = cattle?.isActive;
                      submitGeneration++;
                      loadCatalog();
                    }),
        if (c != null &&
            (widget.productionCategory == null ||
                c.productionCategory == widget.productionCategory)) ...[
          const SizedBox(height: 16),
          Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(c.nameOrId,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                    'Kategori: ${c.productionCategory?.name.toUpperCase() ?? 'belum diklasifikasikan'}'),
                Text(c.estimatedWeight == null
                    ? 'Bobot belum tercatat'
                    : '${kgLabel(c.estimatedWeight!)} kg'),
                Text('${ageEvidenceLabel(c)} · ${c.gender}'),
                if (c.productionCategory == ProductionCategory.beef)
                  Text(
                      'Tujuan: ${beefPurposeLabels[c.modules.beef?.purpose] ?? 'belum dicatat'} · Fase: ${beefPhaseLabels[c.modules.beef?.phase] ?? 'belum dicatat'}'),
                if (c.productionCategory == ProductionCategory.dairy)
                  Text(
                      'Fase: ${dairyPhaseLabels[c.modules.dairy?.phase] ?? 'belum dicatat'} · DIM: ${DairyMetrics(c, now).dim ?? 'belum tersedia'}'),
                TextButton(
                    onPressed: busy || !c.isActive
                        ? null
                        : () => showDialog<bool>(
                            context: context,
                            builder: (_) => WeightEntryDialog(cattle: c)),
                    child: Text(c.estimatedWeight == null
                        ? 'Catat bobot'
                        : 'Perbarui bobot')),
              ])),
          if (c.productionCategory == ProductionCategory.dairy)
            const InfoBanner(CattleNutritionContext.dairyLimitations,
                warning: true),
        ],
        if (issue != null) InfoBanner(issue, warning: true),
        if (issue != null && c?.isActive == true)
          TextButton.icon(
              onPressed: busy
                  ? null
                  : () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => CattleProfileScreen(cattle: c!))),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Lengkapi profil sapi')),
        if (loading)
          const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator())),
        if (catalogError != null) ...[
          InfoBanner(catalogError!, warning: true),
          TextButton(
              onPressed: busy ? null : loadCatalog,
              child: const Text('Coba muat bahan lagi')),
        ],
        if (catalog != null) ...[
          const SectionHeading('Bahan dan jumlah pakan'),
          const Text(
              'Masukkan pakan segar (as-fed), kg per ekor per hari. Tidak ada jumlah otomatis.'),
          if (catalog!.feeds.isEmpty)
            const InfoBanner('Katalog kategori ini belum memiliki bahan.'),
          Form(
              key: form,
              child: Column(children: [
                if (c?.productionCategory == ProductionCategory.beef &&
                    c?.modules.beef?.purpose == BeefPurpose.fattening) ...[
                  const InfoBanner(
                      'Masukkan target pertambahan bobot harian (ADG) untuk evaluasi penggemukan. Nilai ini terpisah dari target bobot sapi.'),
                  TextFormField(
                      key: const ValueKey('nutrition-target-adg'),
                      controller: targetAdg,
                      enabled: !busy,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Target ADG evaluasi (kg/hari)'),
                      validator: (text) {
                        final value = double.tryParse(
                            (text ?? '').trim().replaceAll(',', '.'));
                        return value == null || !value.isFinite || value <= 0
                            ? 'Isi target ADG lebih besar dari 0 kg/hari.'
                            : null;
                      }),
                ],
                for (final feed in catalog!.feeds)
                  Panel(
                      child: Column(children: [
                    CheckboxListTile(
                        key: ValueKey('feed-select-${feed.feedId}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(feed.displayName),
                        value: chosen.contains(feed.feedId),
                        onChanged: busy
                            ? null
                            : (checked) => setState(() {
                                  if (checked == true) {
                                    chosen.add(feed.feedId);
                                  } else {
                                    chosen.remove(feed.feedId);
                                  }
                                  error = null;
                                })),
                    if (chosen.contains(feed.feedId))
                      TextFormField(
                          key: ValueKey('feed-quantity-${feed.feedId}'),
                          controller: quantities[feed.feedId],
                          enabled: !busy,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Jumlah pakan segar (kg/ekor/hari)'),
                          onChanged: (_) => setState(() {
                                error = null;
                              }),
                          validator: (text) {
                            final kg = double.tryParse(
                                (text ?? '').trim().replaceAll(',', '.'));
                            return kg == null || !kg.isFinite || kg <= 0
                                ? 'Isi jumlah lebih besar dari 0 kg/hari.'
                                : null;
                          }),
                    if (chosen.contains(feed.feedId) &&
                        feed.confidenceNote is String &&
                        (feed.confidenceNote as String).trim().isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(feed.confidenceNote as String,
                              style: Theme.of(context).textTheme.bodySmall)),
                  ])),
              ])),
        ],
        if (error != null) InfoBanner(error!, warning: true),
        if (chosen.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text('${chosen.length} bahan dipilih untuk evaluasi.')),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: busy ||
                    loading ||
                    catalog == null ||
                    catalog!.feeds.isEmpty ||
                    issue != null
                ? null
                : evaluate,
            child: Text(busy ? 'Mengirim evaluasi…' : 'Evaluasi nutrisi')),
      ],
    );
  }
}
