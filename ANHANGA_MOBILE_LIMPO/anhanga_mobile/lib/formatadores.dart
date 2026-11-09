// Funções de formatação do ANHANGÁ.
// Utilizadas pelo aplicativo e pelos testes.

String formatarDuracao(num? minutos) {
  if (minutos == null) {
    return 'Não registrado';
  }

  final total = minutos.round();

  final horas = total ~/ 60;
  final minutosRestantes = total % 60;

  if (horas == 0) {
    return '${minutosRestantes}min';
  }

  return '${horas}h '
      '${minutosRestantes.toString().padLeft(2, '0')}min';
}

String formatarNumeroBR(
  num valor, {
  int casas = 1,
}) {
  return valor
      .toStringAsFixed(casas)
      .replaceAll('.', ',');
}
