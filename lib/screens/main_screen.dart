import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/farm_tab.dart';
import '../state/farm_scope.dart';
import '../widgets/bottom_nav_bar.dart';
import 'cattle/cattle_list_screen.dart';
import 'feed/feed_hub_screen.dart';
import 'groups/group_list_screen.dart';
import 'home/command_center_screen.dart';
import 'profile/user_profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  FarmTab tab = FarmTab.commandCenter;
  String cattleFilter = 'Semua';
  int cattleFilterRequest = 0;
  void showGroups() => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const GroupListScreen()),
      );

  void showCattle(String filter) => setState(
        () {
          cattleFilter = filter;
          cattleFilterRequest++;
          tab = FarmTab.cattle;
        },
      );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: FarmScope.read(context),
        builder: (context, _) => PopScope(
          canPop: tab == FarmTab.commandCenter,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              setState(() => tab = FarmTab.commandCenter);
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: !FarmScope.read(context).ready
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(
                    index: tab.index,
                    children: [
                      CommandCenterScreen(
                        onCattle: showCattle,
                        onGroups: showGroups,
                        onFeed: () => setState(() => tab = FarmTab.feed),
                      ),
                      CattleListScreen(
                        initialFilter: cattleFilter,
                        filterRequest: cattleFilterRequest,
                      ),
                      const FeedHubScreen(),
                      const UserProfileScreen(),
                    ],
                  ),
            bottomNavigationBar: !FarmScope.read(context).ready
                ? null
                : BottomNavBar(
                    selectedIndex: tab,
                    onSelected: (value) => setState(() => tab = value),
                  ),
          ),
        ),
      );
}
