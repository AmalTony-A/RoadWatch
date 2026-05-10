import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'providers/app_state.dart';
import 'features/map/map_provider.dart';
import 'screens/shell_screen.dart';
import 'services/api_service.dart';
import 'services/connectivity_service.dart';
import 'services/local_storage_service.dart';
import 'services/location_service.dart';

void main() {
  runApp(const RoadWatchApp());
}

class RoadWatchApp extends StatelessWidget {
  const RoadWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppState(
            api: ApiService(),
            connectivity: ConnectivityService(),
            localStorage: LocalStorageService(),
            location: LocationService(),
          )..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => MapProvider(),
        ),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: AppConfig.appName,
            theme: _buildTheme(appState.isDarkMode),
            home: const ShellScreen(),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(bool isDark) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final scaffoldBg = isDark ? const Color(0xFF121212) : AppConfig.paper;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : AppConfig.deepNavy;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: AppConfig.deepNavy,
        primary: AppConfig.deepNavy,
        secondary: AppConfig.safeGreen,
        surface: surfaceColor,
        tertiary: AppConfig.cautionYellow,
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shadowColor: AppConfig.deepNavy.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: AppConfig.deepNavy.withValues(alpha: 0.08), thickness: 1),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.transparent,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: textColor,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor.withValues(alpha: isDark ? 0.95 : 0.88),
        indicatorColor: AppConfig.deepNavy.withValues(alpha: 0.12),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppConfig.deepNavy.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppConfig.deepNavy.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppConfig.deepNavy.withValues(alpha: 0.28), width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConfig.deepNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppConfig.deepNavy,
          side: BorderSide(color: AppConfig.deepNavy.withValues(alpha: 0.14)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
