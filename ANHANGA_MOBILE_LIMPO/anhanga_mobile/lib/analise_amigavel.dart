import 'dart:math' as math;

import 'package:flutter/material.dart';

// ANHANGA - Analises amigaveis por jogo e por partida.
// Calcula estatisticas somente a partir dos registros recebidos.

double? _numero(Object? valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString().replaceAll(',', '.'));
}

String _br(num n, [int casas = 2]) =>
    n.toStringAsFixed(casas).replaceAll('.', ',');

String _valor(Object? v, {String unidade = ''}) {
  if (v == null) return 'Aguardando dados';
  final n = _numero(v);
  return n == null ? '$v$unidade' : '${_br(n)}$unidade';
}

Widget _linha(String titulo, String valor) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 380) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: Text(titulo)),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Text(
                valor,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _Resumo {
  _Resumo(List<Map<String, dynamic>> dados)
    : valores = dados
          .map((s) => _numero(s['duracao_minutos']))
          .whereType<double>()
          .where((n) => n >= 0 && n.isFinite)
          .toList() {
    valores.sort();
  }

  final List<double> valores;

  int get quantidade => valores.length;

  double get total => valores.fold<double>(0, (soma, n) => soma + n);

  double get media => quantidade == 0 ? 0 : total / quantidade;

  double get mediana {
    if (quantidade == 0) return 0;
    final meio = quantidade ~/ 2;
    return quantidade.isOdd
        ? valores[meio]
        : (valores[meio - 1] + valores[meio]) / 2;
  }

  double get desvio {
    if (quantidade == 0) return 0;
    final variancia =
        valores.fold<double>(
          0,
          (soma, n) => soma + math.pow(n - media, 2).toDouble(),
        ) /
        quantidade;
    return math.sqrt(variancia);
  }

  double? zScore(double valor) {
    if (quantidade < 2 || desvio == 0) return null;
    return (valor - media) / desvio;
  }

  String interpretar(double valor) {
    final z = zScore(valor);
    if (z == null) return 'Historico insuficiente para comparar';
    if (z >= 2) return 'Muito acima do seu tempo comum';
    if (z >= 1) return 'Acima do seu tempo comum';
    if (z <= -2) return 'Muito abaixo do seu tempo comum';
    if (z <= -1) return 'Abaixo do seu tempo comum';
    return 'Proximo do seu tempo habitual';
  }
}

// Meu Ritmo: estatisticas separadas pelo nome do jogo.
Widget painelJogosAmigavel(
  List<Map<String, dynamic>> sessoes,
  String Function(Map<String, dynamic>) nomeJogo, [
  Widget Function(String nome)? iconeJogo,
]) {
  final grupos = <String, List<Map<String, dynamic>>>{};

  for (final s in sessoes) {
    final nome = nomeJogo(s).trim();
    if (nome.isEmpty) continue;
    grupos.putIfAbsent(nome, () => []).add(s);
  }

  if (grupos.isEmpty) {
    return const SizedBox.shrink();
  }

  final nomes = grupos.keys.toList()
    ..sort((a, b) => grupos[b]!.length.compareTo(grupos[a]!.length));

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            leading: Icon(Icons.sports_esports),
            title: Text(
              'Seus jogos e seus habitos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Veja quanto voce joga em cada titulo'),
          ),
          for (final nome in nomes)
            Builder(
              builder: (context) {
                final registros = grupos[nome]!;
                final resumo = _Resumo(registros);
                final validos = registros
                    .where((s) => _numero(s['duracao_minutos']) != null)
                    .toList();
                final comPausas = validos
                    .where((s) => (_numero(s['quantidade_pausas']) ?? 0) > 0)
                    .length;
                final totalPausas = validos.fold<double>(
                  0,
                  (total, s) => total + (_numero(s['quantidade_pausas']) ?? 0),
                );

                return ExpansionTile(
                  leading:
                      iconeJogo?.call(nome) ??
                      const Icon(Icons.gamepad_outlined),
                  title: Text(nome),
                  subtitle: Text('${registros.length} partidas registradas'),
                  childrenPadding: const EdgeInsets.all(12),
                  children: [
                    _linha('Partidas com duracao', '${resumo.quantidade}'),
                    if (resumo.quantidade > 0) ...[
                      _linha('Tempo total', '${_br(resumo.total)} min'),
                      _linha(
                        'Quanto voce joga por partida',
                        '${_br(resumo.media)} min',
                      ),
                      _linha(
                        'Seu tempo habitual',
                        '${_br(resumo.mediana)} min',
                      ),
                      _linha(
                        'Quanto o tempo varia',
                        '${_br(resumo.desvio)} min',
                      ),
                      _linha(
                        'Partida mais curta',
                        '${_br(resumo.valores.first)} min',
                      ),
                      _linha(
                        'Partida mais longa',
                        '${_br(resumo.valores.last)} min',
                      ),
                      _linha('Pausas realizadas', '${totalPausas.round()}'),
                      _linha('Partidas com pausas', '$comPausas'),
                      _linha(
                        'Partidas sem pausas',
                        '${validos.length - comPausas}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Neste jogo, voce costuma jogar cerca de '
                        '${_br(resumo.media, 0)} minutos por partida. '
                        'Seu tempo habitual e de '
                        '${_br(resumo.mediana, 0)} minutos.',
                      ),
                    ] else
                      const Text('Aguardando duracoes registradas.'),
                  ],
                );
              },
            ),
        ],
      ),
    ),
  );
}

// Partidas: explicacao individual baseada no mesmo jogo.
Widget analisePartidaAmigavel(
  Map<String, dynamic> sessao,
  List<Map<String, dynamic>> sessoes,
  String Function(Map<String, dynamic>) nomeJogo,
) {
  final nome = nomeJogo(sessao);
  final id = sessao['id_fato']?.toString();

  final outras = sessoes.where((s) {
    return nomeJogo(s) == nome &&
        s['id_fato']?.toString() != id &&
        _numero(s['duracao_minutos']) != null;
  }).toList();

  final stats = _Resumo(outras);

  final duracao = _numero(sessao['duracao_minutos']);
  final limite = _numero(sessao['limite_minutos_sessao']);

  final diferencaLimite = duracao != null && limite != null && limite > 0
      ? duracao - limite
      : null;

  final diferencaMedia = duracao != null && stats.quantidade > 0
      ? duracao - stats.media
      : null;

  final z = duracao == null ? null : stats.zScore(duracao);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      const Divider(),

      const Text(
        'Mais informações sobre sua partida',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),

      const SizedBox(height: 8),

      if (diferencaLimite != null)
        _linha(
          diferencaLimite > 0
              ? 'Quanto passou do limite'
              : 'Tempo que restou do limite',
          '${_br(diferencaLimite.abs())} min',
        ),

      if (stats.quantidade > 0) ...[
        _linha('Quanto voce joga neste jogo', '${_br(stats.media)} min'),

        _linha('Seu tempo habitual neste jogo', '${_br(stats.mediana)} min'),

        _linha('Quanto suas partidas variam', '${_br(stats.desvio)} min'),

        if (diferencaMedia != null)
          _linha(
            'Diferenca da media',
            '${diferencaMedia >= 0 ? '+' : ''}'
                '${_br(diferencaMedia)} min',
          ),

        _linha(
          'Comparacao com seu historico',
          duracao == null ? 'Aguardando dados' : stats.interpretar(duracao),
        ),

        _linha('Distancia da media', z == null ? 'Nao calculavel' : _br(z)),
      ] else
        const Text(
          'Ainda nao ha outras partidas deste jogo '
          'para comparar seus habitos.',
        ),

      const SizedBox(height: 8),

      _linha(
        'Mudancas no seu jeito de jogar',
        sessao['score_anomalia'] == null
            ? 'Análise não calculada'
            : _valor(sessao['score_anomalia']),
      ),

      _linha(
        'Conforto do seu ambiente',
        sessao['score_contexto'] == null
            ? 'Sem medições disponíveis'
            : _valor(sessao['score_contexto']),
      ),

      _linha(
        'Tempo estimado pela analise',
        _valor(sessao['duracao_prevista'], unidade: ' min'),
      ),

      if (sessao['temperatura'] != null)
        _linha('Temperatura', _valor(sessao['temperatura'], unidade: ' °C')),

      if (sessao['umidade'] != null)
        _linha('Umidade', _valor(sessao['umidade'], unidade: '%')),

      if (sessao['luminosidade'] != null)
        _linha('Iluminacao', _valor(sessao['luminosidade'], unidade: ' lux')),

      if (sessao['ruido_db'] != null)
        _linha('Ruido ao redor', _valor(sessao['ruido_db'], unidade: ' dB')),

      if (sessao['origem_dados'] != null)
        _linha(
          'Origem dos dados',
          sessao['origem_dados'].toString().trim().toUpperCase() ==
                  'ANHANGA_MOBILE'
              ? 'Aplicativo ANHANGÁ'
              : sessao['origem_dados'].toString(),
        ),
      const SizedBox(height: 4),
    ],
  );
}
