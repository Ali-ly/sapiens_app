import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/cattle_draft.dart';
import '../../widgets/glass_card.dart';
import 'cattle_profile_screen.dart';

class CattleSuccessScreen extends StatelessWidget {
  const CattleSuccessScreen({
    super.key,
    required this.cattle,
  });

  final CattleDraft cattle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassPageBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 520,
              ),
              child: Padding(
                padding: const EdgeInsets.all(
                  24,
                ),
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.successSoft.withOpacity(
                          0.86,
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(
                            0.92,
                          ),
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 58,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(
                      height: 24,
                    ),
                    const Text(
                      'Sapi Berhasil Ditambahkan!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Text(
                      '${cattle.nameOrId} dan hasil estimasi berat awal sudah siap dilihat di profil sapi.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(
                      height: 24,
                    ),
                    GlassCard(
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppColors.warmSurface,
                              borderRadius: BorderRadius.circular(
                                16,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              cattle.placeholderEmoji,
                              style: const TextStyle(
                                fontSize: 30,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cattle.nameOrId,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  '${cattle.gender} · ${cattle.ageMonths} bulan',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${cattle.estimatedWeight?.toStringAsFixed(1) ?? '-'} kg',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CattleProfileScreen(
                                cattle: cattle,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Lihat Profil Sapi',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).popUntil(
                            (route) => route.isFirst,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: const BorderSide(
                            color: AppColors.primary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              16,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Kembali ke Home',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
