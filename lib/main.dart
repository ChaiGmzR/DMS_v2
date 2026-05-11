import 'package:flutter/material.dart';

import 'src/core/api_client.dart';
import 'src/state/app_state.dart';
import 'src/ui/login_screen.dart';
import 'src/ui/shell_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState(ApiClient());
  await appState.load();
  runApp(DmsApp(appState: appState));
}

class DmsApp extends StatelessWidget {
  const DmsApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'DMS Flutter',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(),
          home: appState.isAuthenticated
              ? ShellScreen(appState: appState)
              : LoginScreen(appState: appState),
        );
      },
    );
  }

  ThemeData _buildTheme() {
    const background = Color(0xFF151821);
    const surface = Color(0xFF202431);
    const surfaceAlt = Color(0xFF2A2F3E);
    const green = Color(0xFF3E7B4E);
    const blue = Color(0xFF3B82C4);
    const orange = Color(0xFFE19A3B);

    final scheme = ColorScheme.fromSeed(
      seedColor: green,
      brightness: Brightness.dark,
      primary: green,
      secondary: blue,
      tertiary: orange,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF444A5C)),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: surface,
        selectedIconTheme: IconThemeData(color: Colors.white),
        selectedLabelTextStyle: TextStyle(color: Colors.white),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(green),
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
        dataRowMinHeight: 48,
        dataRowMaxHeight: 58,
      ),
    );
  }
}
