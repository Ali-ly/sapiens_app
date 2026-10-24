import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/cattle.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/photo_preview.dart';
import '../feed/feed_calculator_screen.dart';

class CattleEstimateResultScreen extends StatefulWidget {
  const CattleEstimateResultScreen({super.key, required this.draft});
  final Cattle draft;
  @override
  State<CattleEstimateResultScreen> createState() =>
      _CattleEstimateResultScreenState();
}

class _CattleEstimateResultScreenState
    extends State<CattleEstimateResultScreen> {
  bool busy = false;
  Cattle? saved;
  String? error;
  Future<void> save(bool feed) async {
    if (busy) {
      return;
    }
    setState(
      () {
        busy = true;
        error = null;
      },
    );
    try {
      final d = widget.draft;
      final result = saved ??
          await FarmScope.read(context).recordWeight(
            d.id,
            weightKg: d.estimatedWeight!,
            source: 'ai',
            images: d.latestCheckImages,
            predictionSpread: d.predictionSpread,
            validImages: d.validImages,
            rejectedImages: d.rejectedImages,
            expectedHistoryLength: d.history.length,
          );
      if (!mounted) {
        return;
      }
      setState(() => saved = result);
      if (feed) {
        Navigator.pushReplacement<bool, Cattle>(
          context,
          MaterialPageRoute<bool>(
              builder: (_) => FeedCalculatorScreen(cattleId: result.id)),
          result: result,
        );
      } else {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final spread = d.predictionSpread;
    return FarmPage(
      title: 'Bobot diketahui.\nSekarang, pakannya.',
      subtitle: d.nameOrId,
      eyebrow: 'HASIL ESTIMASI FOTO',
      back: true,
      children: [
        Panel(
          color: AppColors.primaryDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusPill(
                saved == null ? 'ESTIMASI AI' : 'BOBOT TERSIMPAN',
                dark: true,
              ),
              const SizedBox(height: 24),
              Text(
                '${kgLabel(d.estimatedWeight ?? 0)} kg',
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'perkiraan bobot badan',
                style: TextStyle(fontSize: 13, color: Color(0xFFBBC9B7)),
              ),
              if (spread != null) ...[
                const SizedBox(height: 18),
                Text(
                  'Variasi prediksi ±${kgLabel(spread)} kg',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                )
              ],
              const SizedBox(height: 16),
              Text(
                '${d.validImages} foto valid · ${d.rejectedImages} foto tidak digunakan',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFBBC9B7),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Panel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.grass_rounded,
                color: AppColors.primary,
                size: 27,
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lanjutkan ke kebutuhan pakan',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.4,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Gunakan bobot ini untuk menghitung takaran sesuai target dan bahan yang tersedia.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.7,
                        color: AppColors.textSecondary,
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
        if (d.latestCheckImages.isNotEmpty) ...[
          const SectionHeading('Foto pengecekan'),
          SizedBox(
            height: 115,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: d.latestCheckImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: PhotoPreview(
                  image: d.latestCheckImages[i],
                  width: 130,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          )
        ],
        const SizedBox(height: 20),
        const InfoBanner(
          'Hasil foto merupakan estimasi. Gunakan timbangan bila membutuhkan bobot yang pasti. Akurasi bobot memengaruhi ketepatan rekomendasi pakan.',
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: InfoBanner(error!, warning: true),
          ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: busy ? null : () => save(true),
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.grass_rounded, size: 20),
          label: Text(
            busy
                ? 'Memproses…'
                : saved == null
                    ? 'Simpan & hitung pakan'
                    : 'Lanjut hitung pakan',
          ),
        ),
        const SizedBox(height: 9),
        OutlinedButton(
          onPressed: busy ? null : () => save(false),
          child: Text(
            saved == null ? 'Simpan bobot saja' : 'Kembali ke profil sapi',
          ),
        ),
        if (saved == null)
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Ulangi foto'),
          ),
      ],
    );
  }
}
