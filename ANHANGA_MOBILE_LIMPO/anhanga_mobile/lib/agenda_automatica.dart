import 'package:device_calendar/device_calendar.dart';

DateTime horarioLocalAgenda(dynamic data) {
  return DateTime(
    data.year,
    data.month,
    data.day,
    data.hour,
    data.minute,
    data.second,
    data.millisecond,
    data.microsecond,
  );
}

class AgendaAutomatica {
  final DeviceCalendarPlugin _calendario = DeviceCalendarPlugin();

  String? _ultimoAviso;

  Future<String?> verificar({
    required int segundosJogados,
    required int limiteSegundos,
    bool solicitarPermissao = false,
    int minutosPreparacao = 15,
  }) async {
    if (limiteSegundos <= 0) return null;

    try {
      var permissao = await _calendario.hasPermissions();

      if (permissao.data != true && solicitarPermissao) {
        permissao = await _calendario.requestPermissions();
      }

      if (permissao.data != true) {
        return null;
      }

      final agora = DateTime.now();
      final fim = agora.add(const Duration(hours: 24));

      final calendarios = await _calendario.retrieveCalendars();

      if (!calendarios.isSuccess) return null;

      final eventos = <Event>[];

      for (final calendario in calendarios.data ?? <Calendar>[]) {
        if (calendario.id == null) continue;

        final resultado = await _calendario.retrieveEvents(
          calendario.id,
          RetrieveEventsParams(startDate: agora, endDate: fim),
        );

        if (!resultado.isSuccess) continue;

        for (final evento in resultado.data ?? <Event>[]) {
          final inicio = evento.start;

          if (inicio == null || evento.allDay == true) {
            continue;
          }

          if (inicio.isAfter(agora)) {
            eventos.add(evento);
          }
        }
      }

      if (eventos.isEmpty) return null;

      eventos.sort((a, b) => a.start!.compareTo(b.start!));

      final proximo = eventos.first;
      final inicio = horarioLocalAgenda(proximo.start!);

      final prazo = inicio.subtract(Duration(minutes: minutosPreparacao));

      final faltamParaPreparacao = prazo.difference(agora).inMinutes;

      final restantesJogo = ((limiteSegundos - segundosJogados) / 60).ceil();

      String? mensagem;
      String tipo = '';

      if (faltamParaPreparacao <= 0) {
        mensagem =
            'Você tem um compromisso próximo. '
            'Recomendo encerrar a partida agora.';
        tipo = 'urgente';
      } else if (faltamParaPreparacao <= 5) {
        mensagem =
            'Faltam $faltamParaPreparacao minutos '
            'para começar a se preparar para '
            'seu compromisso.';
        tipo = 'preparacao';
      } else if (solicitarPermissao && faltamParaPreparacao < restantesJogo) {
        mensagem =
            'Sua partida pode ultrapassar o horário '
            'de preparação para um compromisso. '
            'Recomendo jogar por menos tempo.';
        tipo = 'inicio';
      }

      if (mensagem == null) return null;

      final identificador = '${inicio.millisecondsSinceEpoch}:$tipo';

      if (_ultimoAviso == identificador) {
        return null;
      }

      _ultimoAviso = identificador;

      return mensagem;
    } catch (_) {
      return null;
    }
  }
}
