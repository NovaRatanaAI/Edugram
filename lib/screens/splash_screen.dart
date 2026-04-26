import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:edugram/providers/user_provider.dart';
import 'package:edugram/responsive/mobile_screen_layout.dart';
import 'package:edugram/responsive/responsive_layout_screen.dart';
import 'package:edugram/responsive/web_screen_layout.dart';
import 'package:edugram/screens/login_screen.dart';
import 'package:edugram/widgets/edugram_wordmark.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Phase 1: intro pop
  late AnimationController _introController;
  late Animation<double> _introScale;
  late Animation<double> _introOpacity;

  // Phase 2: shine sweep
  late AnimationController _shineController;
  late Animation<double> _shineAnim;

  // Phase 3: particle burst
  late AnimationController _particleController;
  final List<_Particle> _particles = [];

  // Phase 4: text fade-in
  late AnimationController _textController;
  late Animation<double> _textOpacity;

  // Phase 5: exit — icon + text fly UP to login logo position
  late AnimationController _exitController;
  late Animation<double> _exitSlide; // eased 0→1
  late Animation<double> _exitFade; // bg/particles fade 1→0
  late Animation<double> _iconShrink; // scale 1 → (86/120)

  // Sizes that EXACTLY match LoginScreen
  static const double _logoSize = 120.0;
  static const double _logoSizeLogin = 86.0; // ClipRRect size in LoginScreen
  static const double _wordmarkH = 52.0; // SvgPicture height in LoginScreen
  static const double _gapLogin = 18.0; // SizedBox between icon & wordmark

  // The wordmark sits INSIDE the same Transform.scale that shrinks icon by
  // (_logoSizeLogin/_logoSize). To land at _wordmarkH after scaling we must
  // declare a compensated height so: _wordmarkRaw * scale == _wordmarkH
  static const double _wordmarkRaw = _wordmarkH * (_logoSize / _logoSizeLogin);

  static const List<Color> _igColors = [
    Color(0xFFf9ce34),
    Color(0xFFee2a7b),
    Color(0xFF6228d7),
    Color(0xFFf09433),
    Color(0xFFdc2743),
    Color(0xFFbc2a8d),
    Color(0xFF405de6),
  ];

  @override
  void initState() {
    super.initState();

    final rng = math.Random();
    for (int i = 0; i < 22; i++) {
      _particles.add(_Particle(
        angle: rng.nextDouble() * 2 * math.pi,
        distance: 90 + rng.nextDouble() * 100,
        size: 3 + rng.nextDouble() * 7,
        color: _igColors[rng.nextInt(_igColors.length)],
      ));
    }

    _introController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _introOpacity =
        CurvedAnimation(parent: _introController, curve: Curves.easeIn);
    _introScale = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.18)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 55),
      TweenSequenceItem(
          tween: Tween(begin: 1.18, end: 0.94)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 25),
      TweenSequenceItem(
          tween: Tween(begin: 0.94, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 20),
    ]).animate(_introController);

    _shineController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shineAnim =
        CurvedAnimation(parent: _shineController, curve: Curves.easeInOut);

    _particleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _textController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _textOpacity =
        CurvedAnimation(parent: _textController, curve: Curves.easeIn);

    _exitController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _exitSlide =
        CurvedAnimation(parent: _exitController, curve: Curves.easeInOut);
    _exitFade = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _exitController, curve: Curves.easeIn));
    _iconShrink = Tween(begin: 1.0, end: _logoSizeLogin / _logoSize).animate(
        CurvedAnimation(parent: _exitController, curve: Curves.easeInOut));

    _runSequence();
  }

  Future<void> _runSequence() async {
    _introController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _particleController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _shineController.forward();
    await Future.delayed(const Duration(milliseconds: 450));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 1100));
    await _exitController.forward();
    if (!mounted) return;
    if (FirebaseAuth.instance.currentUser != null) {
      await Provider.of<UserProvider>(context, listen: false).refreshUser();
      if (!mounted) return;
    }
    final startScreen = FirebaseAuth.instance.currentUser == null
        ? const LoginScreen()
        : const ResponsiveLayout(
            webScreenLayout: WebScreenLayout(),
            mobileScreenLayout: MobileScreenLayout(),
          );
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => startScreen,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _introController.dispose();
    _shineController.dispose();
    _particleController.dispose();
    _textController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    // AppBar height in LoginScreen ≈ kToolbarHeight (56)
    // Login icon top offset = screenH * 0.10 (SizedBox at top of scroll)
    // Icon center in login = topPadding + kToolbarHeight + screenH*0.10 + _logoSizeLogin/2
    final loginIconCenterY =
        topPadding + kToolbarHeight + screenH * 0.10 + _logoSizeLogin / 2 + 35;
    // Splash icon center starts at screenH / 2
    final totalSlide = (screenH / 2) - loginIconCenterY;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _introController,
          _shineController,
          _particleController,
          _textController,
          _exitController,
        ]),
        builder: (context, _) {
          final slideY = -_exitSlide.value * totalSlide;

          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Subtle dark gradient background ──────────────────────────
              Opacity(
                opacity: _introOpacity.value * _exitFade.value,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.4,
                      colors: [
                        Color(0xFF1a0a1a),
                        Color(0xFF0a0a0a),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Particle burst — follows the icon as it rises ────────────
              Opacity(
                opacity: _exitFade.value,
                child: CustomPaint(
                  painter: _ParticlePainter(
                    _particleController.value,
                    _particles,
                    translateY: slideY,
                  ),
                ),
              ),

              // ── Icon + wordmark — BOTH slide up together ─────────────────
              Center(
                child: Transform.translate(
                  offset: Offset(0, slideY),
                  child: Transform.scale(
                    scale: _introScale.value * _iconShrink.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Shine-masked logo — Hero flies it to login screen position
                        Hero(
                          tag: 'ig-logo',
                          child: ShaderMask(
                            shaderCallback: (rect) {
                              final sx = _shineAnim.value;
                              return LinearGradient(
                                begin: Alignment(-1.5 + sx * 3.5, -1),
                                end: Alignment(-0.5 + sx * 3.5, 1),
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.45),
                                  Colors.transparent,
                                ],
                              ).createShader(rect);
                            },
                            blendMode: BlendMode.srcATop,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  22 * (_logoSize / _logoSizeLogin)),
                              child: const _IgLogoWidget(size: _logoSize),
                            ),
                          ),
                        ),

                        SizedBox(
                            height: _gapLogin * (_logoSize / _logoSizeLogin)),

                        // Edugram wordmark — Hero flies it to login screen position
                        Hero(
                          tag: 'ig-wordmark',
                          flightShuttleBuilder: (_, anim, __, ___, ____) =>
                              FadeTransition(
                            opacity: anim,
                            child: const EdugramWordmark(
                              color: Colors.white,
                              height: _wordmarkRaw,
                            ),
                          ),
                          child: Opacity(
                            opacity: _textOpacity.value,
                            child: const EdugramWordmark(
                              color: Colors.white,
                              height: _wordmarkRaw,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── "from Meta" footer — fades out during exit ───────────────
              Positioned(
                bottom: 52,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity:
                      ((_particleController.value * 2) - 1).clamp(0.0, 1.0) *
                          _exitFade.value,
                  child: const Text(
                    'from NUM IT Student',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Instagram icon drawn in Flutter ──────────────────────────────────────────
class _IgLogoWidget extends StatelessWidget {
  final double size;
  const _IgLogoWidget({required this.size});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _IgLogoPainter());
}

class _IgLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Offset.zero & size;

    // 2022 refreshed Instagram gradient: brighter yellow→orange→pink→purple
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          Color(0xFFFFD600), // bright yellow
          Color(0xFFFF7A00), // orange
          Color(0xFFFF0069), // hot pink/magenta
          Color(0xFFD300C4), // purple-magenta
          Color(0xFF7638FA), // violet
        ],
        stops: [0.0, 0.25, 0.50, 0.75, 1.0],
      ).createShader(rect);

    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(s * 0.22)), bgPaint);

    canvas.saveLayer(rect, Paint());

    final whitePaint = Paint()..color = Colors.white;
    final clearPaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;

    // Outer white rounded square border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.10, s * 0.10, s * 0.80, s * 0.80),
          Radius.circular(s * 0.165)),
      whitePaint,
    );
    // Cut out inner area
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.165, s * 0.165, s * 0.67, s * 0.67),
          Radius.circular(s * 0.13)),
      clearPaint,
    );

    // Center lens circle
    final cx = s * 0.50, cy = s * 0.50;
    canvas.drawCircle(Offset(cx, cy), s * 0.228, whitePaint);
    canvas.drawCircle(Offset(cx, cy), s * 0.148, clearPaint);

    // Viewfinder dot — top RIGHT (2022 refresh)
    canvas.drawCircle(Offset(s * 0.685, s * 0.315), s * 0.068, whitePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Particle burst ────────────────────────────────────────────────────────────
class _Particle {
  final double angle;
  final double distance;
  final double size;
  final Color color;
  const _Particle(
      {required this.angle,
      required this.distance,
      required this.size,
      required this.color});
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;
  final double translateY;

  _ParticlePainter(this.progress, this.particles, {this.translateY = 0});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2 + translateY;
    final dist = Curves.easeOut.transform(progress);
    final opacity = (1 - progress * progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final x = cx + math.cos(p.angle) * p.distance * dist;
      final y = cy + math.sin(p.angle) * p.distance * dist;
      final paint = Paint()..color = p.color.withValues(alpha: opacity * 0.85);
      canvas.drawCircle(Offset(x, y), p.size * (1 - progress * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.progress != progress || old.translateY != translateY;
}

