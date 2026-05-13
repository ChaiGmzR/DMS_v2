import 'package:defect_ms_v2/main.dart';
import 'package:defect_ms_v2/src/core/api_client.dart';
import 'package:defect_ms_v2/src/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('muestra la pantalla de login cuando no hay sesion', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final appState = AppState(ApiClient());
    await appState.load();

    await tester.pumpWidget(
      DmsApp(appState: appState, enableUpdateCheck: false),
    );

    expect(find.text('DMS'), findsOneWidget);
    expect(find.text('Iniciar sesion'), findsOneWidget);
  });
}
