import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../features/cattle/cattle_page.dart';
import '../features/feed/feed_page.dart';
import '../features/home/home_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/settings/backup_actions.dart';
import '../features/settings/settings_page.dart';
import '../ui/components.dart';
import 'theme.dart';

class SapiensApp extends StatelessWidget {
  const SapiensApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'SAPIENS',
      debugShowCheckedModeBanner: false,
      theme: sapiensTheme(),
      home: const AccountGate());
}

class AccountGate extends ConsumerWidget {
  const AccountGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(farmProvider)
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) =>
            PageFrame(title: 'Data belum dapat dibuka', back: false, children: [
          Notice(errorText(e), warning: true),
          const Text(
              'Data yang tersimpan tidak ditimpa. Coba muat ulang atau pulihkan cadangan yang valid.'),
          const SizedBox(height: 20),
          OutlinedButton(
              onPressed: () => ref.invalidate(farmProvider),
              child: const Text('Coba muat ulang')),
          SubmitButton(
              label: 'Pulihkan cadangan',
              submit: () => BackupActions.import(context, ref))
        ]),
        data: (data) => data.account == null
            ? const OnboardingPage()
            : MainShell(
                key:
                    ValueKey('${data.account!.id}-${data.account!.mode.name}')),
      );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
      body: IndexedStack(index: selected, children: const [
        HomePage(),
        CattlePage(),
        FeedPage(),
        SettingsPage()
      ]),
      bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (i) => setState(() => selected = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Beranda'),
            NavigationDestination(
                icon: Icon(Icons.pets_outlined),
                selectedIcon: Icon(Icons.pets),
                label: 'Ternak'),
            NavigationDestination(
                icon: Icon(Icons.grass_outlined),
                selectedIcon: Icon(Icons.grass),
                label: 'Pakan'),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profil')
          ]));
}
