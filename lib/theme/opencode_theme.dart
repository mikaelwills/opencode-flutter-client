import 'package:flutter/material.dart';

/// OpenCode terminal-style theme and colors
class OpenCodeTheme {
  // Terminal color scheme - matching OpenCode
  static const Color background = Color(0xFF0A0A0A); // Very dark background
  static const Color surface = Color(0xFF0d0d0d); // Slightly lighter
  static const Color primary = Color(0xFF00D9FF); // Cyan blue for prompts
  static const Color secondary = Color(0xFF7C3AED); // Purple accent
  static const Color text = Color(0xFFFFFFFF); // Pure white text
  static const Color textSecondary = Color(0xFF888888); // Gray text
  static const Color error = Color(0xFFFF5555); // Bright red for errors
  static const Color warning = Color(0xFFFFB86C); // Orange for warnings
  static const Color success = Color(0xFF50FA7B); // Bright green for success

  /// Get the main theme data for the app
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color scheme
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: primary,
        secondary: secondary,
        onSurface: text,
        onPrimary: background,
        onSecondary: background,
        error: error,
      ),

      // Scaffold theme
      scaffoldBackgroundColor: background,

      // App bar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
      ),

      // Text theme with monospace fonts
      textTheme: OpenCodeTextStyles.textTheme,

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: textSecondary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: textSecondary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary),
        ),
        hintStyle: const TextStyle(color: textSecondary),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// OpenCode terminal-style text styles
class OpenCodeTextStyles {
  // Font family preference: FiraCode > SF Mono > Consolas > monospace
  static const String _fontFamily = 'FiraCode';

  static const TextStyle terminal = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    color: OpenCodeTheme.text,
    height: 1.4,
  );

  static const TextStyle prompt = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    color: OpenCodeTheme.primary,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle code = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    color: OpenCodeTheme.text,
    backgroundColor: OpenCodeTheme.surface,
  );

  static const TextStyle userMessage = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    color: OpenCodeTheme.text,
    height: 1.4,
  );

  static const TextStyle assistantMessage = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    color: OpenCodeTheme.text,
    height: 1.4,
  );

  static const TextStyle toolExecution = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    color: OpenCodeTheme.textSecondary,
    height: 1.3,
  );

  static const TextStyle connectionStatus = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    color: OpenCodeTheme.textSecondary,
    fontWeight: FontWeight.w500,
  );

  /// Complete text theme for the app
  static TextTheme get textTheme {
    return const TextTheme(
      displayLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 32,
        color: OpenCodeTheme.text,
        fontWeight: FontWeight.w300,
      ),
      displayMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 28,
        color: OpenCodeTheme.text,
        fontWeight: FontWeight.w300,
      ),
      displaySmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        color: OpenCodeTheme.text,
        fontWeight: FontWeight.w400,
      ),
      headlineLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 22,
        color: OpenCodeTheme.text,
        fontWeight: FontWeight.w400,
      ),
      headlineMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        color: OpenCodeTheme.text,
        fontWeight: FontWeight.w400,
      ),
      headlineSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 18,
        color: OpenCodeTheme.text,
        fontWeight: FontWeight.w400,
      ),
      titleLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        color: OpenCodeTheme.text,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        color: OpenCodeTheme.text,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        color: OpenCodeTheme.text,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: terminal,
      bodyMedium: terminal,
      bodySmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        color: OpenCodeTheme.text,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        color: OpenCodeTheme.text,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        color: OpenCodeTheme.text,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 10,
        color: OpenCodeTheme.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Terminal UI symbols and constants
class OpenCodeSymbols {
  static const String prompt = '❯';
  static const String pipe = '│';
  static const String cancel = '^C';
  static const String loading = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'; // Spinner frames

  // Connection status indicators
  static const String connected = '●';
  static const String disconnected = '○';
  static const String reconnecting = '◐';
}
