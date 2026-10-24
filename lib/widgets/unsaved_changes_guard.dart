import 'package:flutter/cupertino.dart';

class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard(
      {super.key,
      required this.dirty,
      required this.busy,
      required this.child});
  final bool dirty, busy;
  final Widget child;
  @override
  State<UnsavedChangesGuard> createState() => _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  bool _allowLeave = false, _prompting = false;
  Future<void> _handlePop(bool didPop, Object? result) async {
    if (didPop || _prompting || widget.busy) {
      return;
    }
    _prompting = true;
    final discard = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Perubahan belum disimpan'),
        content: const Text(
          'Kembali ke formulir untuk menyimpan, atau tinggalkan perubahan ini.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Lanjut mengisi'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abaikan perubahan'),
          )
        ],
      ),
    );
    _prompting = false;
    if (discard == true && mounted) {
      setState(() => _allowLeave = true);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          if (mounted) {
            Navigator.maybePop(context);
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _allowLeave || !widget.dirty && !widget.busy,
        onPopInvokedWithResult: _handlePop,
        child: widget.child,
      );
}
