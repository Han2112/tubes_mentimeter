import 'dart:async';

import 'package:flutter/material.dart';

class AppToast {
  static OverlayEntry? _currentToast;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _dismissTimer?.cancel();
    _currentToast?.remove();

    final color = isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    _currentToast = OverlayEntry(
      builder: (context) {
        final topPadding = MediaQuery.of(context).padding.top;

        return Positioned(
          top: topPadding + 16,
          left: 20,
          right: 20,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, -12 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                message,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_currentToast!);
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      _currentToast?.remove();
      _currentToast = null;
    });
  }
}
