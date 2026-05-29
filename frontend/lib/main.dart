import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'providers/app_state.dart';
import 'features/map/map_provider.dart';
import 'screens/shell_screen.dart';
import 'screens/login_screen.dart';
import 'screens/complaint_detail_screen.dart';
import 'services/api_service.dart';
import 'services/connectivity_service.dart';
import 'services/local_storage_service.dart';
import 'services/location_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
            home: const AuthGate(),
            onGenerateRoute: (settings) {
              // Simple route parsing for complaint detail: /complaint/<id>
              final name = settings.name ?? '';
              if (name.startsWith('/complaint/')) {
                final id = name.replaceFirst('/complaint/', '');
                return MaterialPageRoute(builder: (_) => ComplaintDetailScreen(complaintId: id));
              }
              return null;
            },
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

// ─── Auth Gate ───────────────────────────────────────────────────────────────
/// Shown as the initial route. Reads [rw_token] from SharedPreferences once,
/// then navigates to [ShellScreen] (authenticated) or [LoginScreen] (not).
/// On browser refresh the stored token is re-read so the session is preserved.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final appState = context.read<AppState>();
    final authenticated = await appState.checkAuth();
    if (!mounted) return;
    if (authenticated) {
      // Replace with shell — user is logged in
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ShellScreen()),
      );
    } else {
      // Replace with login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Splash while checking auth
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D2137), Color(0xFF1D4E89), Color(0xFF2B6CB0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.route_rounded, color: Colors.white, size: 56),
              SizedBox(height: 20),
              Text(
                'RoadWatch AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 28),
              CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
  }
}
