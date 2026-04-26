import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EdugramWordmark extends StatelessWidget {
  const EdugramWordmark({
    Key? key,
    required this.color,
    required this.height,
  }) : super(key: key);

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'E',
                style: GoogleFonts.merienda(
                  color: color,
                  fontSize: height * 0.86,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: 0,
                  shadows: [
                    Shadow(
                      color: color.withValues(alpha: 0.18),
                      offset: Offset(0, height * 0.035),
                      blurRadius: height * 0.04,
                    ),
                  ],
                ),
              ),
              TextSpan(
                text: 'dugram',
                style: GoogleFonts.lobsterTwo(
                  color: color,
                  fontSize: height * 0.95,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: 0.2,
                  shadows: [
                    Shadow(
                      color: color.withValues(alpha: 0.18),
                      offset: Offset(0, height * 0.035),
                      blurRadius: height * 0.04,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
