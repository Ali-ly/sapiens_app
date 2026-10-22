import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar(
      {super.key, required this.selectedIndex, required this.onSelected});
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
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
                    4,
                    (i) {
                      final selected = i == selectedIndex;
                      return Expanded(
                        child: Semantics(
                          selected: selected,
                          button: true,
                          label: ['Beranda', 'Sapi', 'Pakan', 'Profil'][i],
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onSelected(i);
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
                                    ['Beranda', 'Sapi', 'Pakan', 'Profil'][i],
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
      );
}
