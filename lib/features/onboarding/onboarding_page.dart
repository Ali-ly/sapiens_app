import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../application/providers.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';
import '../settings/backup_actions.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  FarmMode? selected;
  @override
  Widget build(BuildContext context) => PageFrame(
          title: 'SAPIENS',
          back: false,
          subtitle: 'Catatan yang terhubung. Keputusan yang lebih jelas.',
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.agriculture_outlined,
                size: 64, color: Palette.ink),
            const SizedBox(height: 28),
            const Text('Peternakanmu,\npengalamanmu.',
                style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.2,
                    height: 1.1)),
            const SizedBox(height: 16),
            const Text(
                'Pilih satu jenis peternakan. Profil sapi, pencatatan, dan evaluasi pakan akan mengikuti pilihan akun ini.',
                style:
                    TextStyle(fontSize: 16, height: 1.6, color: Palette.muted)),
            const SizedBox(height: 28),
            for (final mode in FarmMode.values)
              Surface(
                  key: ValueKey('mode-${mode.name}'),
                  color: selected == mode ? Palette.leaf : Colors.white,
                  onTap: () => setState(() => selected = mode),
                  child: Row(children: [
                    Icon(
                        mode == FarmMode.beef
                            ? Icons.grass_outlined
                            : Icons.water_drop_outlined,
                        size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(mode.farmer,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                              mode == FarmMode.beef
                                  ? 'Bobot, pemeliharaan, dan pakan.'
                                  : 'Susu, kondisi fisiologis, dan pakan.',
                              style: const TextStyle(color: Palette.muted))
                        ])),
                    Icon(selected == mode
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked)
                  ])),
            const SizedBox(height: 14),
            SubmitButton(
                label: 'Mulai peternakanku',
                enabled: selected != null,
                submit: () async {
                  await ref.read(farmProvider.notifier).start(selected!);
                }),
            const SizedBox(height: 14),
            const Text('Tanpa login cloud · data disimpan di perangkat ini',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Palette.muted)),
            const SizedBox(height: 20),
            SubmitButton(
                label: 'Sudah punya cadangan SAPIENS baru?',
                icon: Icons.restore,
                submit: () => BackupActions.import(context, ref)),
          ]);
}
