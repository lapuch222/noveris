import 'package:device_calendar/device_calendar.dart';

class AgendaPrazoAndroid {
  static Future<int?> buscar({required int limiteSegundos}) async {
    if (limiteSegundos <= 0) return null;

    try {
      final plugin = DeviceCalendarPlugin();

      var permissao = await plugin.hasPermissions();

      if (permissao.data != true) {
        permissao = await plugin.requestPermissions();
      }

      if (permissao.data != true) return null;

      final agora = DateTime.now();
      final fimBusca = agora.add(const Duration(hours: 24));
      final fimPrevisto = agora.add(Duration(seconds: limiteSegundos));

      final resposta = await plugin.retrieveCalendars();
      if (!resposta.isSuccess) return null;

      DateTime? primeiroPrazo;

      for (final calendario in resposta.data ?? <Calendar>[]) {
        final id = calendario.id;
        if (id == null) continue;

        final eventos = await plugin.retrieveEvents(
          id,
          RetrieveEventsParams(startDate: agora, endDate: fimBusca),
        );

        if (!eventos.isSuccess) continue;

        for (final evento in eventos.data ?? <Event>[]) {
          if (evento.allDay == true || evento.start == null) {
            continue;
          }

          final inicio = evento.start!.toLocal();

          if (!inicio.isAfter(agora)) continue;

          // Margem de 15 minutos para preparacao.
          final prazo = inicio.subtract(const Duration(minutes: 15));

          if (!prazo.isBefore(fimPrevisto)) continue;

          if (primeiroPrazo == null || prazo.isBefore(primeiroPrazo)) {
            primeiroPrazo = prazo;
          }
        }
      }

      return primeiroPrazo?.millisecondsSinceEpoch;
    } catch (_) {
      // Falha de calendario nao impede iniciar o jogo.
      return null;
    }
  }
}
