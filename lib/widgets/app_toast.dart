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
    final backgroundColor = isError
        ? const Color(0xFFFFF1F2)
        : const Color(0xFFF0FDF4);
    final borderColor = isError
        ? const Color(0xFFFECACA)
        : const Color(0xFFBBF7D0);
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    _currentToast = OverlayEntry(
      builder: (context) {
        final topPadding = MediaQuery.of(context).padding.top;

        return Positioned(
          top: topPadding + 18,
          left: 16,
          right: 16,
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
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                message,
                                style: TextStyle(
                                  color: const Color(0xFF111827),
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
