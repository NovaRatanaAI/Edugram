import 'package:flutter/material.dart';
import 'colors.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.dark;
  bool get isDarkMode => themeMode == ThemeMode.dark;
  void toggleTheme(bool isOn) {
    themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class MyTheme {
  static ThemeData lightTheme() => ThemeData(
        scaffoldBackgroundColor: lightMobileBackgroundColor,
        primaryColor: const Color.fromARGB(255, 37, 36, 36),
        brightness: Brightness.light,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.black,
          selectionColor: Colors.grey,
          selectionHandleColor: Colors.black,
        ),
        colorScheme: ColorScheme.fromSwatch(brightness: Brightness.light)
            .copyWith(secondary: Colors.grey),
      );

  static ThemeData darkTheme() => ThemeData(
        scaffoldBackgroundColor: mobileBackgroundColor,
        primaryColor: Colors.white,
        brightness: Brightness.dark,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.black,
          selectionColor: Colors.grey,
          selectionHandleColor: Colors.black,
        ),
        colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark)
            .copyWith(secondary: Colors.grey),
      );
}
