import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class AppToast {
  static ToastificationItem? _activeToast;

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final bool isReplacing = _activeToast != null;

    // 1. Instantly remove the active toast item without exit animation
    if (_activeToast != null) {
      toastification.dismiss(_activeToast!, showRemoveAnimation: false);
      _activeToast = null;
    }

    // 2. Show new toast (uses Duration.zero if replacing to prevent re-animating)
    _activeToast = toastification.show(
      context: context,
      title: Text(message),
      style: ToastificationStyle.fillColored,
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 4),
      type: isError ? ToastificationType.error : ToastificationType.success,
      animationDuration: isReplacing
          ? Duration.zero
          : const Duration(milliseconds: 300),
    );
  }
}