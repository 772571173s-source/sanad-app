import 'package:flutter/material.dart';

import 'app_widgets.dart';

String readableError(Object error) => error
    .toString()
    .replaceFirst('Bad state: ', '')
    .replaceFirst('Exception: ', '');

Future<void> runWithFeedback(
    BuildContext context, Future<void> Function() action,
    {String success = 'تم الحفظ بنجاح.',
    String loading = 'جار تنفيذ العملية...'}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Row(
        children: [
          const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(width: 14),
          Expanded(child: Text(loading)),
        ],
      ),
    ),
  );
  try {
    await action();
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) {
      final tone = sanadAlertTone(context, SemanticAlertKind.success);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: tone.background,
          content: Text(success, style: TextStyle(color: tone.foreground)),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) {
      final tone = sanadAlertTone(context, SemanticAlertKind.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: tone.background,
          content: Text(
            readableError(error),
            style: TextStyle(color: tone.foreground),
          ),
        ),
      );
    }
  }
}
