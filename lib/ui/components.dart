import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../api/contracts.dart';
import '../domain/value.dart';

String number(double value, {int digits = 1}) =>
    value.toStringAsFixed(digits).replaceAll('.', ',');
double? numeric(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));
String dateText(DateTime date) =>
    '${date.toLocal().day}/${date.toLocal().month}/${date.toLocal().year}';
String dayText(String date) => dateText(calendar(date));
String errorText(Object e) {
  if (e is FormatException) return e.message;
  if (e is StateError) return e.message;
  if (e is GatewayError) return e.message;
  return 'Proses belum berhasil. Periksa koneksi atau ruang penyimpanan, lalu coba lagi. Data lokal belum diganti.';
}

void toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class PageFrame extends StatelessWidget {
  const PageFrame(
      {super.key,
      required this.title,
      required this.children,
      this.subtitle,
      this.actions,
      this.back = true,
      this.maxWidth = AppLayout.formWidth});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? actions;
  final bool back;
  final double maxWidth;
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = AppLayout.gutter(width);
    return Scaffold(
        appBar: AppBar(
            automaticallyImplyLeading: back,
            titleSpacing: width > maxWidth
                ? ((width - maxWidth) / 2 +
                        gutter -
                        (back && Navigator.canPop(context) ? 56 : 0))
                    .clamp(16, double.infinity)
                : 20,
            title: Text(title),
            actions: actions == null
                ? null
                : [
                    ...actions!,
                    if (width > maxWidth)
                      SizedBox(width: (width - maxWidth) / 2 + gutter - 8),
                  ]),
        body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 40),
                    children: [
                      if (subtitle != null)
                        Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpace.section),
                            child: Text(subtitle!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Palette.muted))),
                      ...children
                    ]))));
  }
}

class Surface extends StatelessWidget {
  const Surface(
      {super.key,
      required this.child,
      this.color = Colors.white,
      this.padding = 20,
      this.onTap});
  final Widget child;
  final Color color;
  final double padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
          color: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppLayout.radius),
              side: BorderSide(
                  color: color == Colors.white
                      ? Palette.line
                      : Colors.transparent)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: Padding(padding: EdgeInsets.all(padding), child: child))));
}

class Heading extends StatelessWidget {
  const Heading(this.text, {super.key, this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
      padding:
          const EdgeInsets.only(top: AppSpace.section, bottom: AppSpace.medium),
      child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Semantics(
                header: true,
                child: Text(text,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.3))),
            if (action != null) action!
          ]));
}

class Notice extends StatelessWidget {
  const Notice(this.text,
      {super.key, this.warning = false, this.error = false});
  final String text;
  final bool warning, error;
  @override
  Widget build(BuildContext context) => Surface(
      color: error
          ? Palette.errorSurface
          : warning
              ? Palette.warningSurface
              : Palette.leaf,
      padding: 16,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(
            error
                ? Icons.error_outline
                : warning
                    ? Icons.info_outline
                    : Icons.lightbulb_outline,
            size: 20,
            color: error
                ? Palette.error
                : warning
                    ? Palette.amber
                    : Palette.ink),
        const SizedBox(width: 10),
        Expanded(
            child:
                Text(text, style: const TextStyle(height: 1.5, fontSize: 14)))
      ]));
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage(
      {super.key, required this.title, required this.message, this.action});
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Surface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.spa_outlined, size: 38, color: Palette.muted),
        const SizedBox(height: 14),
        Text(title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(message,
            style: const TextStyle(color: Palette.muted, height: 1.6)),
        if (action != null) ...[const SizedBox(height: 18), action!]
      ]));
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.warning = false, this.error = false});
  final String text;
  final bool warning, error;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: warning ? Palette.warningSurface : Palette.leaf,
          borderRadius: BorderRadius.circular(9)),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: warning ? Palette.amber : Palette.ink)));
}

class Metric extends StatelessWidget {
  const Metric(
      {super.key,
      required this.label,
      required this.value,
      this.detail,
      this.onTap,
      this.textValue = false});
  final String label, value;
  final String? detail;
  final VoidCallback? onTap;
  final bool textValue;
  @override
  Widget build(BuildContext context) => Surface(
      onTap: onTap,
      child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 104),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Palette.muted, height: 1.4)),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: textValue ? 20 : 26,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.5,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            if (detail != null) ...[
              const SizedBox(height: 10),
              Text(detail!,
                  style: const TextStyle(
                      fontSize: 12, color: Palette.muted, height: 1.5))
            ]
          ])));
}

class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final scaled = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = c.maxWidth < 330 || scaled > 1.3
            ? 1
            : c.maxWidth >= 840 && children.length > 2
                ? 4
                : 2;
        return Column(children: [
          for (var start = 0; start < children.length; start += columns)
            IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  for (var i = start; i < start + columns; i++) ...[
                    if (i > start) const SizedBox(width: AppSpace.medium),
                    Expanded(
                        child: i < children.length
                            ? children[i]
                            : const SizedBox.shrink())
                  ]
                ]))
        ]);
      });
}

/// Navigation tabs share anatomy while retaining Material keyboard/selection semantics.
class SectionTab extends StatelessWidget {
  const SectionTab(
      {super.key,
      required this.label,
      required this.selected,
      required this.onSelected,
      this.chipKey});
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Key? chipKey;
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: selected ? Palette.ink : Colors.transparent,
                  width: 2))),
      child: ChoiceChip(
          key: chipKey,
          label: Text(label),
          selected: selected,
          onSelected: onSelected,
          color: const WidgetStatePropertyAll(Palette.cream),
          showCheckmark: false,
          backgroundColor: Palette.cream,
          selectedColor: Palette.cream,
          disabledColor: Palette.cream,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: onSelected == null
                  ? Palette.muted.withOpacity(.6)
                  : selected
                      ? Palette.ink
                      : Palette.muted),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))));
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Memuat data',
      liveRegion: true,
      child: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LinearProgressIndicator(
                            value: MediaQuery.disableAnimationsOf(context)
                                ? .5
                                : null,
                            backgroundColor: Palette.leaf,
                            color: Palette.ink,
                            minHeight: 3),
                        const SizedBox(height: 20),
                        const Text('Memuat data…',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Palette.muted)),
                      ])))));
}

class SubmitButton extends StatefulWidget {
  const SubmitButton(
      {super.key,
      required this.label,
      required this.submit,
      this.icon = Icons.check,
      this.enabled = true,
      this.secondary = false});
  final String label;
  final Future<void> Function() submit;
  final IconData icon;
  final bool enabled, secondary;
  @override
  State<SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<SubmitButton> {
  bool busy = false;
  String? error;
  Future<void> run() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.submit();
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.secondary ? Palette.ink : Colors.white))
        : Icon(widget.icon, size: 20);
    final label = Text(busy ? 'Memproses…' : widget.label);
    final submit = busy || !widget.enabled ? null : run;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (error != null)
        Semantics(liveRegion: true, child: Notice(error!, error: true)),
      if (widget.secondary)
        OutlinedButton.icon(onPressed: submit, icon: icon, label: label)
      else
        FilledButton.icon(onPressed: submit, icon: icon, label: label)
    ]);
  }
}

Future<String?> chooseDay(BuildContext context, String current,
    {bool allowFuture = false}) async {
  final now = DateTime.now();
  final initial = calendar(current);
  final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(1900),
      lastDate: allowFuture ? DateTime(now.year + 20) : now);
  return selected == null ? null : day(selected);
}

class DraftGuard extends StatefulWidget {
  const DraftGuard({super.key, required this.dirty, required this.child});
  final bool dirty;
  final Widget child;
  @override
  State<DraftGuard> createState() => _DraftGuardState();
}

class _DraftGuardState extends State<DraftGuard> {
  bool allowed = false, asking = false;
  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !widget.dirty || allowed,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || asking) return;
        asking = true;
        final yes = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text('Tinggalkan perubahan?'),
                    content: const Text(
                        'Perubahan yang belum disimpan akan hilang.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Lanjut mengisi')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Tinggalkan'))
                    ]));
        asking = false;
        if (yes == true && mounted) {
          setState(() => allowed = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.maybePop(context);
          });
        }
      },
      child: widget.child);
}

Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.push<T>(context, MaterialPageRoute<T>(builder: (_) => page));
