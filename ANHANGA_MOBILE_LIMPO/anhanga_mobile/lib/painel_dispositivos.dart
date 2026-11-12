import 'package:flutter/material.dart';

class PainelDispositivos extends StatelessWidget {
  const PainelDispositivos({
    super.key,
    required this.sessoes,
    required this.destaque,
  });

  final List<Map<String, dynamic>> sessoes;
  final Color destaque;

  double _minutos(Object? valor) {
    if (valor is num) return valor.toDouble();

    return double.tryParse(valor?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  String _nomeDispositivo(Map<String, dynamic> sessao) {
    final plataforma = (sessao['plataforma'] ?? '').toString().toLowerCase();

    if (plataforma == 'pc' || plataforma == 'windows') {
      return 'Computador';
    }

    if (plataforma == 'android' || plataforma == 'smartphone') {
      return 'Smartphone';
    }

    if (plataforma.isEmpty) {
      return 'Nao identificado';
    }

    return sessao['plataforma'].toString();
  }

  String _formatarTempo(double minutos) {
    final total = minutos.round();
    final horas = total ~/ 60;
    final resto = total % 60;

    if (horas == 0) {
      return '${resto}min';
    }

    return '${horas}h ${resto.toString().padLeft(2, '0')}min';
  }

  @override
  Widget build(BuildContext context) {
    final contagem = <String, int>{};
    final tempos = <String, double>{};

    for (final sessao in sessoes) {
      final nome = _nomeDispositivo(sessao);

      contagem[nome] = (contagem[nome] ?? 0) + 1;

      final duracao = _minutos(sessao['duracao_minutos']);

      if (duracao >= 0 && duracao.isFinite) {
        tempos[nome] = (tempos[nome] ?? 0) + duracao;
      }
    }

    final dispositivos = contagem.keys.toList()
      ..sort((a, b) => contagem[b]!.compareTo(contagem[a]!));

    final total = sessoes.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices, color: destaque),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Meus dispositivos de jogo',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text('Partidas registradas: $total'),
            Text('Dispositivos utilizados: ${dispositivos.length}'),

            const Divider(height: 30),

            if (dispositivos.isEmpty)
              const Text('Nenhuma partida registrada neste periodo.'),

            for (final nome in dispositivos) ...[
              Row(
                children: [
                  Icon(
                    nome == 'Computador'
                        ? Icons.computer
                        : nome == 'Smartphone'
                        ? Icons.smartphone
                        : Icons.devices_other,
                    color: destaque,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      nome,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  Text('${contagem[nome]} partidas'),
                ],
              ),

              const SizedBox(height: 10),

              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : contagem[nome]! / total,
                  minHeight: 10,
                  color: destaque,
                  backgroundColor: destaque.withValues(alpha: 0.15),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                '${(contagem[nome]! * 100 / total).toStringAsFixed(1)}%'
                ' das partidas',
              ),

              Text(
                'Tempo jogado: '
                '${_formatarTempo(tempos[nome] ?? 0)}',
              ),

              const SizedBox(height: 20),
            ],

            const Text(
              'Dados calculados apenas com as partidas '
              'disponiveis para sua conta.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
