import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/erp_theme.dart';

/// Global error handling for the Worker Portal.
///
/// Two layers:
///
/// 1. `installGlobalErrorHandlers()` — wires up `FlutterError.onError`,
///    `PlatformDispatcher.onError`, and `ErrorWidget.builder` so any
///    unhandled error anywhere in the framework gets routed here
///    instead of crashing the isolate or showing the red error
///    screen. Errors are logged + surfaced as a small snackbar so
///    the user knows something went wrong without seeing a stack
///    trace.
///
/// 2. `ErrorBoundary` — a widget that catches build-time errors
///    in its subtree and renders a friendly fallback in their
///    place. Wrap the top of every route to contain crashes to a
///    single screen.
///
/// `runZonedGuarded` should be used in `main()` so async errors
/// outside a try/catch (e.g. fire-and-forget `_load()` in a
/// controller's `onInit`) are also caught.
void installGlobalErrorHandlers() {
  // 1. Framework errors during build / layout / paint.
  FlutterError.onError = (FlutterErrorDetails details) {
    _logError(details.exception, details.stack,
        context: details.context?.toString());
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
    _notifyUser(details.exception);
  };

  // 2. Async errors from the platform dispatcher (uncaught Futures).
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    _logError(error, stack);
    _notifyUser(error);
    return true; // handled
  };

  // 3. Custom widget builder so a broken widget shows a small
  //    inline message rather than the giant red error screen.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) return ErrorWidget(details.exception);
    return const _InlineErrorWidget();
  };
}

/// The `runZonedGuarded` handler in `main()`: async errors that reach
/// no try/catch are logged and shown, like every other uncaught error.
void reportZoneError(Object error, StackTrace stack) {
  _logError(error, stack, context: 'zone');
  _notifyUser(error);
}

void _logError(Object error, StackTrace? stack, {String? context}) {
  developer.log(
    'Uncaught error${context != null ? " ($context)" : ""}: $error',
    name: 'WorkerPortal',
    error: error,
    stackTrace: stack,
  );
}

/// Throttled snackbar — many controllers can throw at once during
/// a bad network response; we only show one snackbar per second.
DateTime _lastSnack = DateTime.fromMillisecondsSinceEpoch(0);
void _notifyUser(Object error) {
  final now = DateTime.now();
  if (now.difference(_lastSnack).inMilliseconds < 1000) return;
  _lastSnack = now;
  // Get.snackbar gracefully no-ops if no overlay context yet
  // (e.g. error during the very first frame).
  try {
    if (Get.context == null) return;
    Get.snackbar(
      'Something went wrong',
      _humanise(error),
      backgroundColor: ErpColors.errorRed,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(12),
    );
  } catch (_) {
    // Snackbar itself failed — give up silently.
  }
}

String _humanise(Object error) {
  final s = error.toString();
  // Trim long stack-y descriptions so the snackbar stays readable.
  if (s.length > 140) return '${s.substring(0, 140)}…';
  return s;
}

// ── Top-level error boundary widget ─────────────────────────────
/// Wrap each top-level route in this widget so a thrown build()
/// renders a friendly recovery card instead of taking the whole
/// app down.
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? label;
  const ErrorBoundary({super.key, required this.child, this.label});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _FullScreenFallback(
        message: _humanise(_error!),
        label: widget.label,
        onReset: () => setState(() => _error = null),
      );
    }
    return _CatchingWidget(
      onError: (e, st) {
        _logError(e, st, context: widget.label);
        if (mounted) setState(() => _error = e);
      },
      child: widget.child,
    );
  }
}

class _CatchingWidget extends StatelessWidget {
  final Widget child;
  final void Function(Object, StackTrace) onError;
  const _CatchingWidget({required this.child, required this.onError});

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (ctx) {
      try {
        return child;
      } catch (e, st) {
        onError(e, st);
        return const _InlineErrorWidget();
      }
    });
  }
}

class _InlineErrorWidget extends StatelessWidget {
  const _InlineErrorWidget();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ErpColors.errorRed.withValues(alpha: 0.08),
        border: Border.all(color: ErpColors.errorRed.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(children: [
        Icon(Icons.warning_amber_rounded,
            color: ErpColors.errorRed, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(
              'This section couldn\'t load. Pull to refresh or try again.',
              style: TextStyle(
                  color: ErpColors.errorRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class _FullScreenFallback extends StatelessWidget {
  final String message;
  final String? label;
  final VoidCallback onReset;
  const _FullScreenFallback({
    required this.message,
    required this.onReset,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        title: const Text('Something went wrong',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: ErpColors.errorRed, size: 56),
              const SizedBox(height: 14),
              Text(
                label != null
                    ? 'The $label screen hit a problem.'
                    : 'This screen hit a problem.',
                style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'No data was lost. You can try again or head back to '
                'the dashboard.',
                style: TextStyle(
                    color: ErpColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ErpColors.bgMuted,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ErpColors.borderLight),
                ),
                child: Text(message,
                    style: const TextStyle(
                        color: ErpColors.textMuted,
                        fontSize: 11,
                        fontFamily: 'monospace')),
              ),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (Get.key.currentState?.canPop() ?? false) {
                        Get.back();
                      }
                      onReset();
                    },
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ErpColors.accentBlue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onReset,
                    child: const Text('Try again'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
