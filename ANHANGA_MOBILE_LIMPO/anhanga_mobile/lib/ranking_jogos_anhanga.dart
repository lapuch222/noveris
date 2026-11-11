import 'package:flutter/material.dart';

class EstatisticaJogo {
  EstatisticaJogo(this.nome);

  final String nome;
  int mobile = 0;
  int pc = 0;

  int get total => mobile + pc;
}

String plataformaRanking(Object? valor) {
  final p = (valor ?? '').toString().toLowerCase();

  if (p.contains('android') ||
      p.contains('mobile') ||
      p.contains('celular') ||
      p.contains('smartphone') ||
      p == 'ios') {
    return 'mobile';
  }

  if (p == 'pc' ||
      p.contains('windows') ||
      p.contains('computador') ||
      p.contains('desktop')) {
    return 'pc';
  }

  return 'outro';
}

List<EstatisticaJogo> calcularRanking(
  List<Map<String, dynamic>> sessoes,
  String Function(Map<String, dynamic>) nomeJogo,
) {
  final mapa = <String, EstatisticaJogo>{};

  for (final sessao in sessoes) {
    final plataforma = plataformaRanking(sessao['plataforma']);

    if (plataforma == 'outro') continue;

    final nome = nomeJogo(sessao).trim();

    if (nome.isEmpty || nome == 'Jogo não informado') {
      continue;
    }

    final chave = nome.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (chave.isEmpty) continue;

    final jogo = mapa.putIfAbsent(chave, () => EstatisticaJogo(nome));

    if (plataforma == 'mobile') {
      jogo.mobile++;
    } else {
      jogo.pc++;
    }
  }

  return mapa.values.toList();
}

List<EstatisticaJogo> ordenarRanking(List<EstatisticaJogo> jogos, String tipo) {
  int valor(EstatisticaJogo j) {
    if (tipo == 'mobile') return j.mobile;
    if (tipo == 'pc') return j.pc;
    return j.total;
  }

  final lista = List<EstatisticaJogo>.from(jogos);

  lista.sort((a, b) {
    final diferenca = valor(b).compareTo(valor(a));
    return diferenca != 0 ? diferenca : a.nome.compareTo(b.nome);
  });

  return lista;
}

Widget painelRankingAvancado({
  required List<Map<String, dynamic>> sessoes,
  required String Function(Map<String, dynamic>) nomeJogo,
  required Widget Function(String) iconeJogo,
  required Color destaque,
}) {
  final jogos = calcularRanking(sessoes, nomeJogo);

  final mobile = ordenarRanking(
    jogos.where((j) => j.mobile > 0).toList(),
    'mobile',
  );

  final pc = ordenarRanking(jogos.where((j) => j.pc > 0).toList(), 'pc');

  final ambos = ordenarRanking(
    jogos.where((j) => j.mobile > 0 && j.pc > 0).toList(),
    'ambos',
  ).take(3).toList();

  final totalMobile = jogos.fold<int>(0, (total, jogo) => total + jogo.mobile);

  final totalPc = jogos.fold<int>(0, (total, jogo) => total + jogo.pc);

  final totalPartidas = totalMobile + totalPc;

  const corMobile = Color(0xFF27CBA6);
  const corPc = Color(0xFF66B8EC);
  const corFundo = Color(0xFF10202A);

  Widget painel(String titulo, Widget conteudo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF29414B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          conteudo,
        ],
      ),
    );
  }

  Widget barras(List<EstatisticaJogo> ranking, String tipo, Color cor) {
    if (ranking.isEmpty) {
      return const Text(
        'Nenhuma partida registrada.',
        style: TextStyle(color: Colors.white70),
      );
    }

    final cinco = ranking.take(5).toList();

    final maior = tipo == 'pc' ? cinco.first.pc : cinco.first.mobile;

    return Column(
      children: [
        for (final jogo in cinco) ...[
          Row(
            children: [
              SizedBox(width: 38, height: 38, child: iconeJogo(jogo.nome)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  jogo.nome,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              Text(
                '${tipo == 'pc' ? jogo.pc : jogo.mobile}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: maior == 0
                  ? 0
                  : (tipo == 'pc' ? jogo.pc : jogo.mobile) / maior,
              backgroundColor: const Color(0xFF2A414A),
              color: cor,
            ),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }

  Widget graficoPlataformas() {
    if (totalPartidas == 0) {
      return const Text(
        'Nenhuma partida registrada.',
        style: TextStyle(color: Colors.white70),
      );
    }

    final proporcao = totalMobile / totalPartidas;

    return Row(
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 15,
                  color: corPc,
                ),
              ),
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: proporcao,
                  strokeWidth: 15,
                  color: corMobile,
                ),
              ),
              Text(
                '$totalPartidas',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🟢 Celular: $totalMobile',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                '🔵 PC: $totalPc',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                '${(proporcao * 100).toStringAsFixed(1)}% no celular',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget podium() {
    if (ambos.isEmpty) {
      return const Text(
        'Ainda não há jogos registrados nos dois dispositivos.',
        style: TextStyle(color: Colors.white70),
      );
    }

    const medalhas = ['🥇', '🥈', '🥉'];

    return Column(
      children: [
        for (var i = 0; i < ambos.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(medalhas[i], style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              SizedBox(width: 38, height: 38, child: iconeJogo(ambos[i].nome)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ambos[i].nome,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${ambos[i].total} partidas',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: ambos[i].mobile,
                          child: Container(height: 12, color: corMobile),
                        ),
                        Expanded(
                          flex: ambos[i].pc,
                          child: Container(height: 12, color: corPc),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Celular ${ambos[i].mobile} • PC ${ambos[i].pc}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 20),
      Text(
        'Seus jogos em números',
        style: TextStyle(
          color: destaque,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Ranking pela quantidade de partidas registradas.',
        style: TextStyle(color: Colors.white70),
      ),
      const SizedBox(height: 16),
      painel('Distribuição: celular e PC', graficoPlataformas()),
      painel('Top 5 jogos no celular', barras(mobile, 'mobile', corMobile)),
      painel('Top 5 jogos no PC', barras(pc, 'pc', corPc)),
      painel('Top 3 nos dois dispositivos 🏆', podium()),
    ],
  );
}
