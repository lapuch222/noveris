
import 'package:flutter_test/flutter_test.dart';
import 'package:anhanga_mobile/formatadores.dart';

void main() {
  group('ANHANGÁ - Formatação de duração', () {
    test('779 minutos devem resultar em 12h 59min', () {
      expect(
        formatarDuracao(779),
        '12h 59min',
      );
    });

    test('90 minutos devem resultar em 1h 30min', () {
      expect(
        formatarDuracao(90),
        '1h 30min',
      );
    });

    test('45 minutos devem resultar em 45min', () {
      expect(
        formatarDuracao(45),
        '45min',
      );
    });
  });

  group('ANHANGÁ - Formatação brasileira', () {
    test('86.56 deve resultar em 86,6', () {
      expect(
        formatarNumeroBR(86.56),
        '86,6',
      );
    });
  });
}
