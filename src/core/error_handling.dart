import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../features/PurchaseOrder/services/theme.dart';

/// Global error handling for the admin app.
///
/// Without it, an error nobody caught — a `Future` started in a
/// controller's `onInit` that fails, a widget that throws while building
/// a bad record — either closed the app or painted the red error screen,
/// and left nothing behind to say what happened.
///
/// `installGlobalErrorHandlers()` routes every such error to one place:
/// it is logged (with its stack, under the name `JarvisAdmin`), and the
/// person sees a short message instead of a crash. In release builds a
/// widget that fails to build shows a small notice in its own place, so
/// the rest of the screen keeps working. Debug builds keep Flutter's
/// red screen, which is what a developer wants.
///
/// `main()` also runs inside `runZonedGuarded`, with
/// [reportZoneError] as its handler, for async errors outside the
/// framework. The same approach as the Worker Portal's
/// `core/error_boundary.dart`.
void installGlobalErrorHandlers() {
  // Errors during build, layout and paint.
  FlutterError.onError = (FlutterErrorDetails details) {
    _log(details.exception, details.stack, context: details.context?.toString());
    if (kDebugMode) FlutterError.dumpErrorToConsole(details);
    _notify(details.exception);
  };

  // Uncaught asynchronous errors reaching the platform dispatcher.
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    _log(error, stack);
    _notify(error);
    return true; // handled: keep the app running
  };

  // A widget that fails to build: a small notice in its place.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) return ErrorWidget(details.exception);
    return const _InlineError();
  };
}

/// The `runZonedGuarded` handler in `main()`.
void reportZoneError(Object error, StackTrace stack) {
  _log(error, stack, context: 'zone');
  _notify(error);
}

void _log(Object error, StackTrace? stack, {String? context}) {
  developer.log(
    'Uncaught error${context != null ? " ($context)" : ""}: $error',
    name: 'JarvisAdmin',
    error: error,
    stackTrace: stack,
  );
}

/// At most one message a second: one bad response can make several
/// controllers fail at once, and a stack of identical messages helps
/// nobody.
DateTime _lastNotice = DateTime.fromMillisecondsSinceEpoch(0);

void _notify(Object error) {
  final now = DateTime.now();
  if (now.difference(_lastNotice).inMilliseconds < 1000) return;
  _lastNotice = now;
  try {
    // No overlay yet (an error in the very first frame): log only.
    if (Get.context == null) return;
    Get.snackbar(
      'Something went wrong',
      _short(error),
      backgroundColor: ErpColors.solidError,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(12),
    );
  } catch (_) {
    // The message itself failed; the error is already logged.
  }
}

String _short(Object error) {
  final s = error.toString();
  return s.length > 140 ? '${s.substring(0, 140)}…' : s;
}

class _InlineError extends StatelessWidget {
  const _InlineError();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            "This part couldn't be shown. Go back and open it again.",
            style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }
}
