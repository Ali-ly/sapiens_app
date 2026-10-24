import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/cattle.dart';
import '../../models/selected_image.dart';
import '../../services/image_service.dart';
import '../../services/weight_service.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/photo_preview.dart';
import 'cattle_estimate_result_screen.dart';

class CattlePhotoScreen extends StatefulWidget {
  const CattlePhotoScreen({
    super.key,
    required this.draft,
    this.imageService,
  });

  final Cattle draft;
  final ImageService? imageService;

  @override
  State<CattlePhotoScreen> createState() => _CattlePhotoScreenState();
}

class _CattlePhotoScreenState extends State<CattlePhotoScreen> {
  late final service = widget.imageService ?? ImageService();
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

      if (!mounted) {
        return;
      }

      final accepted = picked
          .where((p) => p.bytes.length <= 8 * 1024 * 1024)
          .take(4 - images.length)
          .toList();

      setState(
        () {
          images.addAll(accepted);

          error = picked.length > accepted.length
              ? 'Maksimal 4 foto, masing-masing hingga 8 MB. '
                  'Foto lainnya tidak ditambahkan.'
              : null;
        },
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => error = camera
              ? 'Kamera belum dapat dibuka. '
                  'Periksa izin kamera atau pilih foto dari galeri.'
              : 'Galeri belum dapat dibuka. '
                  'Periksa izin foto dan coba lagi.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> estimate() async {
    if (images.isEmpty) {
      setState(() => error = 'Tambahkan minimal 1 foto sapi.');
      return;
    }

    setState(
      () {
        busy = true;
        error = null;
      },
    );

    try {
      final estimate = await WeightService.predictWeight(images);

      if (!mounted) {
        return;
      }

      final draft = widget.draft.copyWith(
        images: [...widget.draft.images, ...images],
        latestCheckImages: List.of(images),
        estimatedWeight: estimate.weightKg,
        predictionSpread: estimate.predictionSpread,
        clearPrediction: estimate.predictionSpread == null,
        validImages: estimate.validImages,
        rejectedImages: estimate.rejectedImages,
      );

      Navigator.pushReplacement<Cattle, Cattle>(
        context,
        MaterialPageRoute<Cattle>(
            builder: (_) => CattleEstimateResultScreen(draft: draft)),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => error = errorMessage(
            e,
            fallback: 'Estimasi belum berhasil. Periksa koneksi layanan, '
                'lalu coba lagi dengan foto yang jelas.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FarmPage(
        title: 'Kenali bobotnya.\nRencanakan pakannya.',
        subtitle: widget.draft.nameOrId,
        eyebrow: 'CEK BOBOT · FOTO SAPI',
        back: true,
        children: [
          const Panel(
            color: AppColors.primarySoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  CupertinoIcons.camera,
                  color: AppColors.primary,
                  size: 30,
                ),
                SizedBox(height: 16),
                Text(
                  'Foto yang jelas,\nestimasi lebih terarah.',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.7,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'Ambil dari samping. Pastikan seluruh tubuh sapi terlihat, '
                  'pencahayaan cukup, dan sapi tidak tertutup objek lain.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.7,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusPill('1–4 foto'),
                    StatusPill('Satu sapi per pengecekan'),
                  ],
                ),
              ],
            ),
          ),
          SectionHeading(
            'Foto pengecekan',
            action: StatusPill('${images.length}/4 foto'),
          ),
          if (images.isEmpty)
            const Panel(
              child: Column(
                children: [
                  SizedBox(height: 14),
                  Icon(
                    CupertinoIcons.photo_on_rectangle,
                    color: AppColors.textSecondary,
                    size: 46,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Belum ada foto sapi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Pilih foto atau ambil langsung dengan kamera.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 14),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: images.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PhotoPreview(
                      image: images[i],
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: IconButton(
                        tooltip: 'Hapus foto ${i + 1}',
                        onPressed: busy
                            ? null
                            : () => setState(
                                  () => images.removeAt(i),
                                ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(.9),
                          minimumSize: const Size(44, 44),
                        ),
                        icon: const Icon(
                          CupertinoIcons.xmark,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      busy || images.length >= 4 ? null : () => pick(false),
                  icon: const Icon(
                    CupertinoIcons.photo,
                    size: 19,
                  ),
                  label: const Text('Galeri'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      busy || images.length >= 4 ? null : () => pick(true),
                  icon: const Icon(
                    CupertinoIcons.camera,
                    size: 19,
                  ),
                  label: const Text('Kamera'),
                ),
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: InfoBanner(
                error!,
                warning: true,
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: busy ? null : estimate,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.auto_awesome_outlined,
                    size: 19,
                  ),
            label: Text(
              busy ? 'Memproses…' : 'Estimasi bobot',
            ),
          ),
          const SizedBox(height: 16),
          const InfoBanner(
            'Foto digunakan untuk memperoleh estimasi bobot melalui layanan AI. '
            'Hasilnya menjadi dasar perkiraan pakan, '
            'bukan pengganti timbangan resmi.',
          ),
        ],
      );
}
