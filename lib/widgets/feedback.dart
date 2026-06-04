import 'package:flutter/material.dart';

Future<void> runWithFeedback(BuildContext context, Future<void> Function() action, {String success = 'تم الحفظ بنجاح.'}) async {
  try {
    await action();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    }
  }
}
