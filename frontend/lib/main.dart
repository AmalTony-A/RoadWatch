import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'providers/app_state.dart';
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
    return ChangeNotifierProvider(
      create: (_) => AppState(
        api: ApiService(),
        connectivity: ConnectivityService(),
        localStorage: LocalStorageService(),
        location: LocationService(),
      )..initialize(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConfig.appName,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppConfig.paper,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppConfig.deepNavy,
            primary: AppConfig.deepNavy,
            secondary: AppConfig.safeGreen,
            surface: Colors.white,
            tertiary: AppConfig.cautionYellow,
          ),
          textTheme: GoogleFonts.spaceGroteskTextTheme(),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shadowColor: AppConfig.deepNavy.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            margin: EdgeInsets.zero,
          ),
          dividerTheme: DividerThemeData(color: AppConfig.deepNavy.withValues(alpha: 0.08), thickness: 1),
          splashFactory: InkSparkle.splashFactory,
          visualDensity: VisualDensity.standard,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: AppConfig.deepNavy,
            elevation: 0,
            centerTitle: false,
            scrolledUnderElevation: 0,
            toolbarHeight: 72,
            titleTextStyle: GoogleFonts.spaceGrotesk(
              color: AppConfig.deepNavy,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white.withValues(alpha: 0.88),
            indicatorColor: AppConfig.deepNavy.withValues(alpha: 0.12),
            elevation: 0,
            labelTextStyle: WidgetStateProperty.all(
              GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
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
        ),
        home: const ShellScreen(),
      ),
    );
  }
}
