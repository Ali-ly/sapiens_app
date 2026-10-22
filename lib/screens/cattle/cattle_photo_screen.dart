import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/cattle_draft.dart';
import '../../models/selected_image.dart';
import '../../services/api_service.dart';
import '../../services/image_service.dart';
import '../../widgets/farm_ui.dart';
import 'cattle_estimate_result_screen.dart';

class CattlePhotoScreen extends StatefulWidget {
  const CattlePhotoScreen(
      {super.key, required this.draft, this.isRecheck = false});
  final CattleDraft draft;
  final bool isRecheck;
  @override
  State<CattlePhotoScreen> createState() => _CattlePhotoScreenState();
}

class _CattlePhotoScreenState extends State<CattlePhotoScreen> {
  final service = ImageService();
  final List<SelectedImage> images = [];
  bool busy = false;
  String? error;
  Future<void> pick(bool camera) async {
    if (images.length >= 4) {
      showError(context, 'Maksimal 4 foto per pengecekan.');
      return;
    }
    setState(() => busy = true);
    try {
      final selected = camera ? await service.takePhoto() : null;
      final picked = camera
          ? (selected == null ? <SelectedImage>[] : [selected])
          : await service.pickImages();
      if (!mounted) return;
      final accepted = picked
          .where((p) => p.bytes.length <= 8 * 1024 * 1024)
          .take(4 - images.length)
          .toList();
      setState(() {
        images.addAll(accepted);
        error = picked.length > accepted.length
            ? 'Maksimal 4 foto, masing-masing hingga 8 MB. Foto lainnya tidak ditambahkan.'
            : null;
      });
    } catch (_) {
      if (mounted)
        setState(() => error = camera
            ? 'Kamera belum dapat dibuka. Periksa izin kamera atau pilih foto dari galeri.'
            : 'Galeri belum dapat dibuka. Periksa izin foto dan coba lagi.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> estimate() async {
    if (images.isEmpty) {
      setState(() => error = 'Tambahkan minimal 1 foto sapi.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await ApiService.predictWeight(images);
      final weight = (data['estimated_weight_kg'] as num?)?.toDouble();
      if (weight == null || !weight.isFinite || weight < 1 || weight > 2000)
        throw const FormatException(
            'Layanan belum mengembalikan bobot yang valid. Coba foto lain.');
      final spread = (data['prediction_spread_kg'] as num?)?.toDouble();
      if (spread != null && (!spread.isFinite || spread < 0))
        throw const FormatException(
            'Hasil estimasi belum valid. Silakan coba lagi.');
      if (!mounted) return;
      final draft = widget.draft.copyWith(
          images: [...widget.draft.images, ...images],
          latestCheckImages: List.of(images),
          estimatedWeight: weight,
          predictionSpread: spread,
          clearPrediction: spread == null,
          validImages: (data['num_valid_images'] as num?)?.toInt() ?? 0,
          rejectedImages: (data['rejected_files'] as List? ?? []).length);
      final saved = await Navigator.push<CattleDraft>(
          context,
          MaterialPageRoute(
              builder: (_) => CattleEstimateResultScreen(
                  draft: draft, isRecheck: widget.isRecheck)));
      if (saved != null && mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted)
        setState(() => error = e is FormatException
            ? e.message
            : e is Exception
                ? e.toString().replaceFirst('Exception: ', '')
                : 'Estimasi belum berhasil. Periksa koneksi layanan, lalu coba lagi dengan foto yang jelas.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FarmPage(
          title: 'Kenali bobotnya.\nRencanakan pakannya.',
          subtitle: widget.draft.nameOrId,
          eyebrow: 'CEK BOBOT · FOTO SAPI',
          back: true,
          children: [
            Panel(
                color: AppColors.primarySoft,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(CupertinoIcons.camera,
                          color: AppColors.primary, size: 30),
                      const SizedBox(height: 16),
                      const Text('Foto yang jelas,\nestimasi lebih terarah.',
                          style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.7)),
                      const SizedBox(height: 14),
                      const Text(
                          'Ambil dari samping. Pastikan seluruh tubuh sapi terlihat, pencahayaan cukup, dan sapi tidak tertutup objek lain.',
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.7,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 18),
                      Wrap(spacing: 8, runSpacing: 8, children: const [
                        StatusPill('1–4 foto'),
                        StatusPill('Satu sapi per pengecekan')
                      ])
                    ])),
            SectionHeading('Foto pengecekan',
                action: StatusPill('${images.length}/4 foto')),
            if (images.isEmpty)
              Panel(
                  child: Column(children: [
                const SizedBox(height: 14),
                const Icon(CupertinoIcons.photo_on_rectangle,
                    color: AppColors.textSecondary, size: 46),
                const SizedBox(height: 16),
                const Text('Belum ada foto sapi',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Pilih foto atau ambil langsung dengan kamera.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 14)
              ]))
            else
              GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: images.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12),
                  itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(21),
                      child: Stack(fit: StackFit.expand, children: [
                        Image.memory(images[i].bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Icon(CupertinoIcons.photo))),
                        Positioned(
                            right: 6,
                            top: 6,
                            child: IconButton(
                                tooltip: 'Hapus foto ${i + 1}',
                                onPressed: busy
                                    ? null
                                    : () => setState(() => images.removeAt(i)),
                                style: IconButton.styleFrom(
                                    backgroundColor:
                                        Colors.white.withOpacity(.9),
                                    minimumSize: const Size(44, 44)),
                                icon:
                                    const Icon(CupertinoIcons.xmark, size: 16)))
                      ]))),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed:
                          busy || images.length >= 4 ? null : () => pick(false),
                      icon: const Icon(CupertinoIcons.photo, size: 19),
                      label: const Text('Galeri'))),
              const SizedBox(width: 12),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed:
                          busy || images.length >= 4 ? null : () => pick(true),
                      icon: const Icon(CupertinoIcons.camera, size: 19),
                      label: const Text('Kamera')))
            ]),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: InfoBanner(error!, warning: true)),
            const SizedBox(height: 24),
            FilledButton.icon(
                onPressed: busy ? null : estimate,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_outlined, size: 19),
                label: Text(busy ? 'Memproses…' : 'Estimasi bobot')),
            const SizedBox(height: 16),
            const InfoBanner(
                'Foto digunakan untuk memperoleh estimasi bobot melalui layanan AI. Hasilnya menjadi dasar perkiraan pakan, bukan pengganti timbangan resmi.'),
          ]);
}
