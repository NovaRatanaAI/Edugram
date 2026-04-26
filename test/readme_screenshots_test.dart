import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edugram/providers/user_provider.dart';
import 'package:edugram/screens/login_screen.dart';
import 'package:edugram/screens/signup_screen.dart';
import 'package:edugram/utils/my_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;

  Future<void> pumpShowcase(
    WidgetTester tester,
    Widget screen, {
    required Size size,
    ThemeMode themeMode = ThemeMode.dark,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final themeProvider = ThemeProvider()..themeMode = themeMode;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: MyTheme.lightTheme(),
          darkTheme: MyTheme.darkTheme(),
          home: screen,
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 800));
  }

  testWidgets('captures login screen for README', (tester) async {
    await pumpShowcase(
      tester,
      const LoginScreen(),
      size: const Size(430, 932),
      themeMode: ThemeMode.dark,
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/edugram-login.png'),
    );
  });

  testWidgets('captures signup screen for README', (tester) async {
    await pumpShowcase(
      tester,
      const SignUpScreen(),
      size: const Size(520, 1180),
      themeMode: ThemeMode.light,
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/edugram-signup.png'),
    );
  });
}

