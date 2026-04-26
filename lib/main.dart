import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:edugram/firebase_options.dart';
import 'package:edugram/providers/user_provider.dart';
import 'package:edugram/resources/local_store.dart';
import 'package:edugram/resources/presence_service.dart';
import 'package:edugram/screens/splash_screen.dart';
import 'package:edugram/utils/app_navigator.dart';
import 'package:edugram/utils/my_theme.dart';
import 'package:edugram/widgets/message_notification_banner.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSize = 300;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20;
  await LocalStore.instance.init();

  final firebaseOptions = DefaultFirebaseOptions.currentPlatform;
  if (firebaseOptions != null) {
    await Firebase.initializeApp(options: firebaseOptions);
  } else {
    await Firebase.initializeApp();
  }
  PresenceService.instance.start();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ],
      builder: (context, _) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Edugram',
          themeMode: themeProvider.themeMode,
          theme: MyTheme.lightTheme(),
          darkTheme: MyTheme.darkTheme(),
          themeAnimationDuration: const Duration(milliseconds: 260),
          themeAnimationCurve: Curves.easeOut,
          builder: (context, child) {
            return MessageNotificationBanner(
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}

