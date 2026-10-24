import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class FarmPage extends StatelessWidget {
  const FarmPage(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.children,
      this.action,
      this.back = false,
      this.eyebrow = 'SAPIENS · TEMAN PETERNAKANMU'});
  final String title, subtitle, eyebrow;
  final List<Widget> children;
  final Widget? action;
  final bool back;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 660),
              child: ListView(
                key: PageStorageKey(title),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  22,
                  18,
                  22,
                  28 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  Row(
                    children: [
                      if (back) ...[
                        IconButton(
                          tooltip: 'Kembali',
                          onPressed: () => Navigator.maybePop(context),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            minimumSize: const Size(44, 44),
                          ),
                          icon: const Icon(
                            CupertinoIcons.chevron_back,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10)
                      ],
                      Expanded(
                        child: Text(
                          eyebrow,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (action != null) action!
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.3,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      );
}
