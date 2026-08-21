import 'package:flutter/foundation.dart';

class RelavoiLogger {
  static bool enabled = false;

  static void info(String msg) {
    if (enabled) debugPrint('[Relavoi] $msg');
  }

  static void warn(String msg) {
    if (enabled) debugPrint('[Relavoi WARN] $msg');
  }

  static void error(String msg) {
    if (enabled) debugPrint('[Relavoi ERROR] $msg');
  }
}
