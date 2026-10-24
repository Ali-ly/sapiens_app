import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_colors.dart';
import '../models/farm_tab.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar(
      {super.key, required this.selectedIndex, required this.onSelected});
  final FarmTab selectedIndex;
  final ValueChanged<FarmTab> onSelected;
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.9),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Row(
                      children: List.generate(
                        FarmTab.values.length,
                        (i) {
                          final tab = FarmTab.values[i];
                          final selected = tab == selectedIndex;
                          return Expanded(
                            child: Semantics(
                              selected: selected,
                              button: true,
                              label: tab.label,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  onSelected(tab);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primaryDark
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        [
                                          CupertinoIcons.square_grid_2x2,
                                          CupertinoIcons.square_stack_3d_up,
                                          Icons.grass_rounded,
                                          CupertinoIcons.person
                                        ][i],
                                        size: 21,
                                        color: selected
                                            ? AppColors.accent
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        tab.label,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
