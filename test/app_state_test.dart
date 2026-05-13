import 'package:defect_ms_v2/src/core/api_client.dart';
import 'package:defect_ms_v2/src/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('load descarta sesiones persistidas de ejecuciones anteriores', () async {
    SharedPreferences.setMockInitialValues({
      'dms_api_base_url': 'http://192.168.1.10:5000/api',
      'dms_token': 'token-anterior',
      'dms_user':
          '{"id":1,"username":"1746","nombre_completo":"Operador","rol":"Inspector_LQC"}',
    });

    final appState = AppState(ApiClient());
    await appState.load();

    final prefs = await SharedPreferences.getInstance();
    expect(appState.isAuthenticated, isFalse);
    expect(appState.token, isNull);
    expect(appState.user, isNull);
    expect(appState.api.token, isNull);
    expect(prefs.getString('dms_token'), isNull);
    expect(prefs.getString('dms_user'), isNull);
    expect(prefs.getString('dms_api_base_url'), isNull);
    expect(appState.apiBaseUrl, 'http://192.168.1.10:5000/api');
    expect(appState.api.baseUrl, 'http://192.168.1.10:5000/api');
  });
}
