import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Provides tactile vibration and sound click feedback on keypress.
class HapticSoundService {
  static void triggerClick(BuildContext context) {
    try {
      HapticFeedback.lightImpact();
      Feedback.forTap(context);
    } catch (_) {}
  }

  static void triggerHeavy(BuildContext context) {
    try {
      HapticFeedback.mediumImpact();
      Feedback.forLongPress(context);
    } catch (_) {}
  }
}
