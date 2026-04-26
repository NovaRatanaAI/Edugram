import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:edugram/utils/my_theme.dart';
import 'package:provider/provider.dart';

class ChangeThemeButtonWidget extends StatelessWidget {
  const ChangeThemeButtonWidget({Key? key}) : super(key: key);

  static const _duration = Duration(milliseconds: 280);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: GestureDetector(
        onTap: () => themeProvider.toggleTheme(!isDark),
        child: AnimatedContainer(
          duration: _duration,
          curve: _curve,
          width: 76,
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF111827), Color(0xFF374151)]
                  : const [Color(0xFFFFD166), Color(0xFF4CC9F0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : const Color(0xFF4CC9F0))
                    .withValues(alpha: 0.14),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedAlign(
                duration: _duration,
                curve: _curve,
                alignment:
                    isDark ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B1020) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              AnimatedAlign(
                duration: _duration,
                curve: _curve,
                alignment:
                    isDark ? Alignment.centerRight : Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0,
                    end: isDark ? math.pi : 0,
                  ),
                  duration: _duration,
                  curve: _curve,
                  builder: (context, value, child) {
                    return Transform.rotate(angle: value, child: child);
                  },
                  child: Icon(
                    isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                    size: 17,
                    color: isDark
                        ? const Color(0xFFA5B4FC)
                        : const Color(0xFFFFB703),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

