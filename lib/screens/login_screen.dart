import 'package:flutter/material.dart';
import 'package:edugram/providers/user_provider.dart';
import 'package:edugram/resources/auth_methods.dart';
import 'package:edugram/screens/signup_screen.dart';
import 'package:edugram/utils/colors.dart';
import 'package:edugram/utils/global_variables.dart';
import 'package:edugram/widgets/change_theme_button_widget.dart';
import 'package:edugram/widgets/edugram_wordmark.dart';
import 'package:edugram/widgets/text_field_input.dart';
import 'package:provider/provider.dart';

import '../responsive/mobile_screen_layout.dart';
import '../responsive/responsive_layout_screen.dart';
import '../responsive/web_screen_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  bool _isLoading = false;
  String? _errorMessage; // inline error shown below the login button

  // Animate the form elements sliding up + fading in after the icon arrives
  late AnimationController _formController;
  late Animation<double> _formFade;
  late Animation<double> _formSlide;

  @override
  void initState() {
    super.initState();
    _formController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _formFade = CurvedAnimation(parent: _formController, curve: Curves.easeOut);
    _formSlide = Tween(begin: 24.0, end: 0.0).animate(
        CurvedAnimation(parent: _formController, curve: Curves.easeOut));

    // Slight delay so the fade-in from splash finishes first
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _formController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    _formController.dispose();
    super.dispose();
  }

  void loginUser() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null; // clear previous error on new attempt
    });
    String res = await AuthMethods().loginUser(
      email: email,
      password: password,
    );
    if (!mounted) return;
    if (res == 'success') {
      await Provider.of<UserProvider>(context, listen: false).refreshUser();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const ResponsiveLayout(
            webScreenLayout: WebScreenLayout(),
            mobileScreenLayout: MobileScreenLayout(),
          ),
        ),
        (route) => false,
      );
    } else {
      setState(() => _errorMessage = res);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: const [
          ChangeThemeButtonWidget(),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: MediaQuery.of(context).size.width > webScreenSize
              ? EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width / 3)
              : const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              // ── Scrollable main content ─────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.10),

                      // ── Instagram icon ────────────────────────────────
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: const _IgLogoWidget(size: 86),
                      ),

                      const SizedBox(height: 18),

                      // ── Edugram wordmark ──────────────────────────────
                      EdugramWordmark(
                        color: Theme.of(context).primaryColor,
                        height: 52,
                      ),

                      const SizedBox(height: 44),

                      // ── Form ──────────────────────────────────────────
                      AnimatedBuilder(
                        animation: _formController,
                        builder: (context, child) => Opacity(
                          opacity: _formFade.value,
                          child: Transform.translate(
                            offset: Offset(0, _formSlide.value),
                            child: child,
                          ),
                        ),
                        child: Column(
                          children: [
                            TextFieldInput(
                              textEditingController: _emailController,
                              hintText: 'Enter your email',
                              textInputType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => FocusScope.of(context)
                                  .requestFocus(_passwordFocus),
                            ),
                            const SizedBox(height: 20),
                            TextFieldInput(
                              textEditingController: _passwordController,
                              hintText: 'Enter your password',
                              textInputType: TextInputType.text,
                              isPass: true,
                              focusNode: _passwordFocus,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) {
                                if (!_isLoading) loginUser();
                              },
                            ),
                            const SizedBox(height: 20),
                            InkWell(
                              onTap: _isLoading ? null : loginUser,
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                width: double.infinity,
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  // Always use the Instagram gradient —
                                  // same in dark mode as light mode.
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF405de6),
                                      Color(0xFFbc2a8d),
                                      Color(0xFFee2a7b),
                                    ],
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            color: primaryColor,
                                            strokeWidth: 2),
                                      )
                                    : const Text('Log in',
                                        style: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15)),
                              ),
                            ),
                            // ── Inline error message ──────────────────────
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.redAccent, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Sign-up link always pinned to bottom ────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const SignUpScreen())),
                      child: const Text(
                        ' Sign up.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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

// ── Inline Instagram icon (identical to SplashScreen's) ─────────────────────
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

