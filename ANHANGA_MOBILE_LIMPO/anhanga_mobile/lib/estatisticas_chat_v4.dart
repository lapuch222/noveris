import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Painel ANHANGÁ V4.1: até 500 sessões acessíveis ao jogador autenticado.
/// Resolve nomes por id_jogo -> dim_jogo; usa nome_jogo_original como fallback.
/// Não modifica registros do banco de dados.
class EstatisticasChatV4 extends StatefulWidget {
  const EstatisticasChatV4({super.key});

  @override
  State<EstatisticasChatV4> createState() => _EstatisticasChatV4State();
}

class _EstatisticasChatV4State extends State<EstatisticasChatV4> {
  static const Color _cor = Color(0xFF5FD4EC);
  bool _carregando = true;
  String? _erro;
  int _total = 0;
  double _minutos = 0;
  int _pausas = 0;
  int _semNome = 0;
  double _minutosSemNome = 0;
  final Map<String, double> _jogos = {};
  final Map<String, int> _contagemJogos = {};
  final Map<String, double> _plataformas = {};
  final Map<String, double> _dias = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw StateError('Entre na sua conta para ver as estatísticas.');
      }
      final perfil = await client
          .from('dim_usuario')
          .select('id_usuario')
          .eq('auth_user_id', uid)
          .maybeSingle();
      if (perfil == null) {
        throw StateError('Perfil do jogador não encontrado.');
      }

      // A política RLS das tabelas continua sendo aplicada ao usuário logado.
      final dados = await client
          .from('fato_ia')
          .select(
            'id_jogo,nome_jogo_original,plataforma,inicio,duracao_minutos,quantidade_pausas',
          )
          .eq('id_usuario', perfil['id_usuario'])
          .order('inicio', ascending: false)
          .limit(500);
      final jogosCadastrados = await client
          .from('dim_jogo')
          .select('id_jogo,nome_jogo');
      if (!mounted || client.auth.currentUser?.id != uid) {
        return;
      }

      final nomesPorId = <String, String>{};
      for (final linha in jogosCadastrados) {
        final nome = (linha['nome_jogo'] as String?)?.trim() ?? '';
        final id = linha['id_jogo'];
        if (id != null && nome.isNotEmpty) {
          nomesPorId[id.toString()] = nome;
        }
      }
      final jogos = <String, double>{};
      final contagemJogos = <String, int>{};
      final plataformas = <String, double>{};
      final dias = <String, double>{};
      double minutos = 0;
      double minutosSemNome = 0;
      int pausas = 0;
      int semNome = 0;
      final hoje = DateTime.now();
      final inicioPeriodo = DateTime(
        hoje.year,
        hoje.month,
        hoje.day,
      ).subtract(const Duration(days: 6));
      for (var i = 0; i < 7; i++) {
        final dia = inicioPeriodo.add(Duration(days: i));
        dias[_chaveDia(dia)] = 0;
      }
      for (final registro in dados) {
        final tempo = ((registro['duracao_minutos'] as num?)?.toDouble() ?? 0)
            .clamp(0.0, 1440.0)
            .toDouble();
        final pausa = ((registro['quantidade_pausas'] as num?)?.toInt() ?? 0)
            .clamp(0, 10000)
            .toInt();
        minutos += tempo;
        pausas += pausa;

        final id = registro['id_jogo']?.toString();
        final cadastrado = id == null ? '' : (nomesPorId[id] ?? '');
        final original =
            (registro['nome_jogo_original'] as String?)?.trim() ?? '';
        final nome = cadastrado.isNotEmpty ? cadastrado : original;
        if (nome.isEmpty) {
          semNome += 1;
          minutosSemNome += tempo;
        } else {
          jogos[nome] = (jogos[nome] ?? 0) + tempo;
          contagemJogos[nome] = (contagemJogos[nome] ?? 0) + 1;
        }

        final plataforma = (registro['plataforma'] as String?)?.trim() ?? '';
        final tipo = plataforma.isEmpty ? 'Não identificada' : plataforma;
        plataformas[tipo] = (plataformas[tipo] ?? 0) + tempo;
        final valorInicio = registro['inicio'];
        final data = valorInicio == null
            ? null
            : DateTime.tryParse(valorInicio.toString())?.toLocal();
        if (data != null) {
          final chave = _chaveDia(data);
          if (dias.containsKey(chave)) {
            dias[chave] = dias[chave]! + tempo;
          }
        }
      }
      if (!mounted || client.auth.currentUser?.id != uid) {
        return;
      }
      setState(() {
        _total = dados.length;
        _minutos = minutos;
        _pausas = pausas;
        _semNome = semNome;
        _minutosSemNome = minutosSemNome;
        _jogos
          ..clear()
          ..addAll(jogos);
        _contagemJogos
          ..clear()
          ..addAll(contagemJogos);
        _plataformas
          ..clear()
          ..addAll(plataformas);
        _dias
          ..clear()
          ..addAll(dias);
        _carregando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e is StateError ? e.message : 'Não foi possível carregar as estatísticas. Verifique a conexão e as permissões.';
          _carregando = false;
        });
      }
    }
  }

  String _chaveDia(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';
  String _horas(double min) => '${(min / 60).toStringAsFixed(1)} h';
  String _duracao(double min) {
    final inteiro = min.round();
    final h = inteiro ~/ 60;
    final m = inteiro % 60;
    return h > 0 ? '${h}h ${m}min' : '${m}min';
  }

  Widget _indicador(String titulo, String valor, IconData icone) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icone, color: _cor),
            const SizedBox(height: 7),
            Text(
              valor,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _grafico(
    String titulo,
    Map<String, double> valores, {
    int limite = 6,
    bool medalhas = false,
  }) {
    final itens = valores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final selecionados = itens.take(limite).toList();
    final maior = selecionados.isEmpty
        ? 1.0
        : selecionados.first.value.clamp(1.0, 1000000000.0).toDouble();
    const emblemas = ['🥇', '🥈', '🥉'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (selecionados.isEmpty)
              const Text('Sem jogos identificados neste período.'),
            for (var i = 0; i < selecionados.length; i++) ...[
              Row(
                children: [
                  if (medalhas && i < 3) ...[
                    Text(emblemas[i], style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(
                      selecionados[i].key,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_duracao(selecionados[i].value)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (selecionados[i].value / maior).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(_cor),
                ),
              ),
              const SizedBox(height: 13),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rankingPartidas() {
    final ordenados = _contagemJogos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const emblemas = ['🥇', '🥈', '🥉'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mais jogados por número de partidas',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (ordenados.isEmpty) const Text('Nenhum jogo identificado.'),
            for (var i = 0; i < ordenados.length && i < 5; i++) ...[
              Row(
                children: [
                  if (i < 3) ...[
                    Text(emblemas[i], style: const TextStyle(fontSize: 19)),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(
                      ordenados[i].key,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('${ordenados[i].value} partidas'),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _evolucao() {
    final maximo = _dias.values.fold<double>(1, (a, b) => b > a ? b : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tempo por dia — últimos 7 dias',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 155,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final dia in _dias.entries)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${dia.value.round()}m',
                              style: const TextStyle(fontSize: 10),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              height: 100 * dia.value / maximo,
                              decoration: BoxDecoration(
                                color: _cor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(dia.key, style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Estatísticas'),
      actions: [
        IconButton(
          onPressed: _carregando ? null : _carregar,
          icon: const Icon(Icons.refresh),
          tooltip: 'Atualizar',
        ),
      ],
    ),
    body: _carregando
        ? const Center(child: CircularProgressIndicator())
        : _erro != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_erro!, textAlign: TextAlign.center),
            ),
          )
        : RefreshIndicator(
            onRefresh: _carregar,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Text(
                  'Resumo das sessões ANHANGÁ',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    _indicador('Partidas', '$_total', Icons.sports_esports),
                    _indicador('Tempo', _horas(_minutos), Icons.timer),
                    _indicador('Pausas', '$_pausas', Icons.self_improvement),
                  ],
                ),
                _evolucao(),
                _grafico('Ranking por tempo jogado', _jogos, medalhas: true),
                _rankingPartidas(),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sessões sem identificação',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_semNome partidas • ${_duracao(_minutosSemNome)}',
                        ),
                        const Text(
                          'Essas sessões não entram no ranking de jogos.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                _grafico('Tempo por plataforma', _plataformas),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Duração média por partida: ${_duracao(_total == 0 ? 0 : _minutos / _total)}.',
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    'Indicadores de até 500 sessões recentes acessíveis à sua conta. '
                    'Nomes recuperados por id_jogo ou pelo nome original; '
                    'os registros sem nome ficam separados. O gráfico diário '
                    'utiliza o horário local do aparelho.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
  );
}
