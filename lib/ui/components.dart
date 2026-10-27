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
      this.back = true});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? actions;
  final bool back;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: back,
          title: Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 21)),
          actions: actions),
      body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    if (subtitle != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(subtitle!,
                              style: const TextStyle(
                                  color: Palette.muted, height: 1.5))),
                    ...children
                  ]))));
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
              borderRadius: BorderRadius.circular(22),
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
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      child: Row(children: [
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3))),
        if (action != null) action!
      ]));
}

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.warning = false});
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => Surface(
      color: warning ? const Color(0xFFFFF0D9) : const Color(0xFFE9F0E5),
      padding: 16,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(warning ? Icons.info_outline : Icons.lightbulb_outline,
            size: 20, color: warning ? Palette.amber : Palette.ink),
        const SizedBox(width: 10),
        Expanded(
            child:
                Text(text, style: const TextStyle(height: 1.5, fontSize: 13)))
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
  const Tag(this.text, {super.key, this.warning = false});
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: warning ? const Color(0xFFFFE6C2) : Palette.leaf,
          borderRadius: BorderRadius.circular(9)),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: warning ? Palette.amber : Palette.ink)));
}

class Metric extends StatelessWidget {
  const Metric(
      {super.key,
      required this.label,
      required this.value,
      this.detail,
      this.onTap});
  final String label, value;
  final String? detail;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Surface(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Palette.muted)),
        const SizedBox(height: 10),
        Text(value,
            style: const TextStyle(
                fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -.8)),
        if (detail != null) ...[
          const SizedBox(height: 7),
          Text(detail!,
              style: const TextStyle(
                  fontSize: 12, color: Palette.muted, height: 1.4))
        ]
      ]));
}

class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, c) => Wrap(spacing: 12, children: [
            for (final child in children)
              SizedBox(
                  width: c.maxWidth < 350 ? c.maxWidth : (c.maxWidth - 12) / 2,
                  child: child)
          ]));
}

class SubmitButton extends StatefulWidget {
  const SubmitButton(
      {super.key,
      required this.label,
      required this.submit,
      this.icon = Icons.check,
      this.enabled = true});
  final String label;
  final Future<void> Function() submit;
  final IconData icon;
  final bool enabled;
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
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (error != null) Notice(error!, warning: true),
        FilledButton.icon(
            onPressed: busy || !widget.enabled ? null : run,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(widget.icon, size: 20),
            label: Text(busy ? 'Memproses…' : widget.label))
      ]);
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
