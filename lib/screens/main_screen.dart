import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../state/farm_store.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home/home_screen.dart';
import 'cattle/cattle_list_screen.dart';
import 'feed/feed_hub_screen.dart';
import 'profile/user_profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int index = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!FarmStore.instance.ready) FarmStore.instance.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmStore.instance,
      builder: (context, _) => Scaffold(
          backgroundColor: AppColors.backgroundTop,
          body: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 660),
                  child: !FarmStore.instance.ready
                      ? const Center(child: CircularProgressIndicator())
                      : Scaffold(
                          backgroundColor: AppColors.background,
                          body: IndexedStack(index: index, children: [
                            HomeScreen(
                                onSeeAll: () => setState(() => index = 1),
                                onFeed: () => setState(() => index = 2)),
                            const CattleListScreen(),
                            const FeedHubScreen(),
                            const UserProfileScreen()
                          ]),
                          bottomNavigationBar: BottomNavBar(
                              selectedIndex: index,
                              onSelected: (v) =>
                                  setState(() => index = v)))))));
}
