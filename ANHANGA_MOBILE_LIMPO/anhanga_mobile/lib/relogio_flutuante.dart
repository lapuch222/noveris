
import 'package:flutter/services.dart';

class RelogioFlutuante {
  static const _canal =
      MethodChannel('com.noveris.anhanga_mobile/relogio');

  static Future<bool> temPermissao() async =>
      await _canal.invokeMethod<bool>(
        'temPermissaoSobreposicao',
      ) ?? false;

  static Future<void> solicitarPermissao() =>
      _canal.invokeMethod<void>(
        'solicitarPermissaoSobreposicao',
      );

  static Future<void> iniciar({
    required String jogo,
    required int limiteSegundos,
  }) =>
      _canal.invokeMethod<void>(
        'iniciarSessao',
        {
          'jogo': jogo,
          'limiteSegundos': limiteSegundos,
        },
      );

  static Future<void> pausar() =>
      _canal.invokeMethod<void>('pausarSessao');

  static Future<void> continuar() =>
      _canal.invokeMethod<void>('continuarSessao');

  static Future<void> encerrar() =>
      _canal.invokeMethod<void>('encerrarSessao');

  static Future<Map<String, dynamic>> obterEstado() async {
    final resultado =
        await _canal.invokeMapMethod<String, dynamic>(
      'obterEstado',
    );

    return resultado ?? {};
  }

  static Future<List<Map<String, dynamic>>>
      obterSessoesPendentes() async {
    final resposta =
        await _canal.invokeMethod<List<dynamic>>(
      'obterSessoesPendentes',
    );

    return (resposta ?? [])
        .map(
          (item) => Map<String, dynamic>.from(
            item as Map,
          ),
        )
        .toList();
  }

  static Future<bool> confirmarSessaoSalva(
    String sessaoUuid,
  ) async {
    return await _canal.invokeMethod<bool>(
          'confirmarSessaoSalva',
          {'sessaoUuid': sessaoUuid},
        ) ??
        false;
  }
}
