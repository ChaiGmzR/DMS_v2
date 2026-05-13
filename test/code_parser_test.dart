import 'package:defect_ms_v2/src/core/code_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extrae codigo EBR desde texto plano', () {
    expect(
      extractPartCode('ebr80757421922407030048'),
      'EBR80757421922407030048',
    );
  });

  test('extrae codigo desde URL', () {
    expect(
      extractPartCode('https://mes.local/scan?codigo=EBR242123069220001'),
      'EBR242123069220001',
    );
  });

  test('extrae codigo desde JSON', () {
    expect(
      extractPartCode('{"codigo":"EBR874637609220777","linea":"M3"}'),
      'EBR874637609220777',
    );
  });

  test('extrae codigo desde etiqueta', () {
    expect(
      extractPartCode('Linea: M1\nCodigo de parte: EBR80757421922407030048'),
      'EBR80757421922407030048',
    );
  });

  test('regresa null para texto vacio', () {
    expect(extractPartCode('   '), isNull);
  });
}
