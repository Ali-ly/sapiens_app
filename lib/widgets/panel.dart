import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class Panel extends StatelessWidget {
  const Panel(
      {super.key,
      required this.child,
      this.color = Colors.white,
      this.padding = 20});
  final Widget child;
  final Color color;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(26),
          border:
              Border.all(color: color == Colors.white ? Colors.white : color),
          boxShadow: color == Colors.white
              ? [
                  BoxShadow(
                    color: AppColors.primaryDark.withOpacity(.025),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: child,
      );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key, this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.4,
                ),
              ),
            ),
            if (action != null) action!
          ],
        ),
      );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label,
      {super.key, this.warning = false, this.dark = false});
  final String label;
  final bool warning, dark;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withOpacity(.1)
              : warning
                  ? AppColors.warningSoft
                  : AppColors.primarySoft,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: dark
                ? AppColors.accent
                : warning
                    ? AppColors.warning
                    : AppColors.primary,
          ),
        ),
      );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel(
      {super.key, required this.title, required this.message, this.action});
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Panel(
        child: Column(
          children: [
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.square_stack_3d_up,
                color: AppColors.primary,
                size: 27,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                letterSpacing: -.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            if (action != null)
              Padding(padding: const EdgeInsets.only(top: 18), child: action!),
            const SizedBox(height: 5)
          ],
        ),
      );
}

class StatTile extends StatelessWidget {
  const StatTile(this.value, this.label, this.icon,
      {super.key, this.warning = false});
  final String value, label;
  final IconData icon;
  final bool warning;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Panel(
          padding: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 18,
                color: warning ? AppColors.warning : AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              )
            ],
          ),
        ),
      );
}

class InfoBanner extends StatelessWidget {
  const InfoBanner(this.message, {super.key, this.warning = false});
  final String message;
  final bool warning;
  @override
  Widget build(BuildContext context) => Panel(
        padding: 15,
        color: warning ? AppColors.warningSoft : AppColors.primarySoft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              warning
                  ? CupertinoIcons.exclamationmark_circle
                  : CupertinoIcons.info_circle,
              size: 18,
              color: warning ? AppColors.warning : AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color:
                      warning ? const Color(0xFF86602C) : AppColors.primaryDark,
                ),
              ),
            )
          ],
        ),
      );
}
