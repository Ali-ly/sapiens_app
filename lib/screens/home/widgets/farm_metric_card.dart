import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class FarmMetricCard extends StatelessWidget {
  const FarmMetricCard(
      {super.key,
      required this.value,
      required this.label,
      required this.icon,
      required this.width,
      required this.onTap});
  final String value, label;
  final IconData icon;
  final double width;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Semantics(
          button: true,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: AppColors.primary),
                    const SizedBox(height: 14),
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 23,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
