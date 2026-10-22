import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/cattle_draft.dart';
import '../state/farm_store.dart';
import '../screens/cattle/cattle_profile_screen.dart';

String dateLabel(DateTime d) => '${d.day} ${[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ][d.month - 1]} ${d.year}';
String kgLabel(double n) => n.toStringAsFixed(1).replaceAll('.', ',');
void showError(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('FormatException: ', '')
            .replaceFirst('Exception: ', ''))));

class FarmPage extends StatelessWidget {
  const FarmPage(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.children,
      this.action,
      this.back = false,
      this.eyebrow = 'SAPITA · TEMAN PETERNAKANMU'});
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
                      padding: EdgeInsets.fromLTRB(22, 18, 22,
                          28 + MediaQuery.paddingOf(context).bottom),
                      children: [
                        Row(children: [
                          if (back) ...[
                            IconButton(
                                tooltip: 'Kembali',
                                onPressed: () => Navigator.maybePop(context),
                                style: IconButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    minimumSize: const Size(44, 44)),
                                icon: const Icon(CupertinoIcons.chevron_back,
                                    size: 18)),
                            const SizedBox(width: 10)
                          ],
                          Expanded(
                              child: Text(eyebrow,
                                  style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                      color: AppColors.textSecondary))),
                          if (action != null) action!
                        ]),
                        const SizedBox(height: 16),
                        Text(title,
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.3,
                                height: 1.15)),
                        const SizedBox(height: 8),
                        Text(subtitle,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.5)),
                        const SizedBox(height: 24),
                        ...children,
                      ])))));
}

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
                      offset: const Offset(0, 6))
                ]
              : []),
      child: child);
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key, this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 14),
      child: Row(children: [
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.4))),
        if (action != null) action!
      ]));
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
          borderRadius: BorderRadius.circular(9)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: dark
                  ? AppColors.accent
                  : warning
                      ? AppColors.warning
                      : AppColors.primary)));
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel(
      {super.key, required this.title, required this.message, this.action});
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Panel(
          child: Column(children: [
        const SizedBox(height: 5),
        Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
                color: AppColors.primarySoft, shape: BoxShape.circle),
            child: const Icon(CupertinoIcons.square_stack_3d_up,
                color: AppColors.primary, size: 27)),
        const SizedBox(height: 18),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -.4)),
        const SizedBox(height: 8),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.6)),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 18), child: action!),
        const SizedBox(height: 5)
      ]));
}

class CattleAvatar extends StatelessWidget {
  const CattleAvatar({super.key, required this.cattle, this.size = 58});
  final CattleDraft cattle;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(size * .3)),
      clipBehavior: Clip.antiAlias,
      child: cattle.images.isNotEmpty
          ? Image.memory(cattle.images.first.bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => CustomPaint(painter: CowPortrait()))
          : CustomPaint(painter: CowPortrait()));
}

class CowPortrait extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final horn = Paint()..color = const Color(0xFFBAC7A4);
    final face = Paint()..color = const Color(0xFFF8FAEE);
    final ink = Paint()..color = AppColors.primaryDark;
    final ears = Paint()..color = const Color(0xFF84966A);
    canvas.drawOval(const Rect.fromLTWH(8, 29, 29, 15), ears);
    canvas.drawOval(const Rect.fromLTWH(63, 29, 29, 15), ears);
    final left = Path()
      ..moveTo(33, 35)
      ..quadraticBezierTo(14, 28, 25, 16)
      ..quadraticBezierTo(24, 29, 40, 29)
      ..close();
    canvas.drawPath(left, horn);
    final right = Path()
      ..moveTo(67, 35)
      ..quadraticBezierTo(86, 28, 75, 16)
      ..quadraticBezierTo(76, 29, 60, 29)
      ..close();
    canvas.drawPath(right, horn);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(27, 28, 46, 49), const Radius.circular(19)),
        face);
    canvas.drawOval(const Rect.fromLTWH(26, 57, 48, 24), horn);
    canvas.drawCircle(const Offset(39, 48), 2.8, ink);
    canvas.drawCircle(const Offset(61, 48), 2.8, ink);
    canvas.drawOval(const Rect.fromLTWH(37, 66, 5, 4), ink);
    canvas.drawOval(const Rect.fromLTWH(58, 66, 5, 4), ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CattleTile extends StatelessWidget {
  const CattleTile({super.key, required this.cattle});
  final CattleDraft cattle;
  @override
  Widget build(BuildContext context) {
    final store = FarmStore.instance;
    final ready = store.planReady(cattle);
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => CattleProfileScreen(cattle: cattle))),
                child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(children: [
                      CattleAvatar(cattle: cattle),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(cattle.nameOrId,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -.3)),
                            const SizedBox(height: 5),
                            Text('${cattle.gender} · ${cattle.ageMonths} bulan',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            Text(
                                ready
                                    ? 'Pakan siap'
                                    : store.needsCheck(cattle)
                                        ? 'Perbarui bobot'
                                        : 'Belum ada rencana pakan',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: ready
                                        ? AppColors.primary
                                        : AppColors.warning))
                          ])),
                      const SizedBox(width: 8),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                cattle.estimatedWeight == null
                                    ? '—'
                                    : kgLabel(cattle.estimatedWeight!),
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -.8)),
                            const Text('kg',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary))
                          ]),
                      const SizedBox(width: 6),
                      const Icon(CupertinoIcons.chevron_right,
                          size: 13, color: AppColors.textSecondary)
                    ])))));
  }
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon,
                size: 18,
                color: warning ? AppColors.warning : AppColors.primary),
            const SizedBox(height: 16),
            Text(value,
                style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1)),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary))
          ])));
}

class InfoBanner extends StatelessWidget {
  const InfoBanner(this.message, {super.key, this.warning = false});
  final String message;
  final bool warning;
  @override
  Widget build(BuildContext context) => Panel(
      padding: 15,
      color: warning ? AppColors.warningSoft : AppColors.primarySoft,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(
            warning
                ? CupertinoIcons.exclamationmark_circle
                : CupertinoIcons.info_circle,
            size: 18,
            color: warning ? AppColors.warning : AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: warning
                        ? const Color(0xFF86602C)
                        : AppColors.primaryDark)))
      ]));
}
