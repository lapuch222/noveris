import 'dart:async';
import 'dart:math' as math;

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// ANHANGÁ — Agenda Inteligente.
/// Lê somente os eventos locais com consentimento. Não envia eventos à nuvem.
/// A recomendação de horário é baseada em regras e no histórico de sessões;
/// a previsão de ML do ANHANGÁ poderá ser integrada separadamente.
class AgendaInteligente extends StatefulWidget {
  const AgendaInteligente({super.key});

  @override
  State<AgendaInteligente> createState() => _AgendaInteligenteState();
}

class _AgendaInteligenteState extends State<AgendaInteligente> {
  final DeviceCalendarPlugin _calendario = DeviceCalendarPlugin();
  bool _ocupado = false;
  bool _autorizado = false;
  String _mensagem = 'Consulte sua agenda para planejar o tempo de jogo.';
  List<Event> _eventos = [];
  int _minutosParaPreparacao = 15;
  int _duracaoHabitual = 60;
  bool _historicoDisponivel = false;
  int _limiteEscolhido = 60;
  bool _limiteCarregado = false;
  Timer? _temporizadorAgenda;

  @override
  void initState() {
    super.initState();

    _carregarLimiteEscolhido();

    _temporizadorAgenda = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _temporizadorAgenda?.cancel();
    super.dispose();
  }

  double _duracaoAtual = 0;
  double _limiteMinutos = 60;
  int _pausas = 0;
  bool _analisandoRisco = false;
  double? _pontuacaoModelo;
  String _classificacaoModelo = '';
  String _avisoModelo = 'Configure a sessão e consulte a previsão.';

  String _hora(DateTime data) =>
      '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';

  String _data(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';

  Future<void> _carregarLimiteEscolhido() async {
    try {
      final cliente = Supabase.instance.client;
      final usuario = cliente.auth.currentUser;

      if (usuario == null) return;

      final dados = await cliente
          .from('dim_usuario')
          .select('limite_minutos_sessao')
          .eq('auth_user_id', usuario.id)
          .maybeSingle();

      final valor = dados?['limite_minutos_sessao'];

      final limite = valor is num
          ? valor.toInt()
          : int.tryParse(valor?.toString() ?? '');

      if (limite == null || limite <= 0 || !mounted) {
        return;
      }

      setState(() {
        _limiteEscolhido = limite;
        _limiteMinutos = limite.toDouble();
        _pontuacaoModelo = null;
        _limiteCarregado = true;
      });
    } catch (erro) {
      debugPrint('Erro ao carregar limite: $erro');
    }
  }

  Future<void> _carregarDuracaoHistorica() async {
    try {
      if (Supabase.instance.client.auth.currentUser == null) return;
      // A RLS do projeto limita o acesso às sessões do próprio usuário.
      final resposta = await Supabase.instance.client
          .from('fato_ia')
          .select('duracao_minutos')
          .order('id_fato', ascending: false)
          .limit(50);
      final minutos = <double>[];
      for (final item in resposta) {
        final valor = item['duracao_minutos'];
        final numero = valor is num
            ? valor.toDouble()
            : double.tryParse(valor?.toString() ?? '');
        if (numero != null && numero > 0 && numero <= 1440) {
          minutos.add(numero);
        }
      }
      if (minutos.isNotEmpty && mounted) {
        final media = minutos.reduce((a, b) => a + b) / minutos.length;
        setState(() {
          _duracaoHabitual = media.round().clamp(10, 240).toInt();
          _historicoDisponivel = true;
        });
      }
    } catch (_) {
      // Mantém duração-padrão caso o histórico esteja indisponível.
    }
  }

  Future<void> _consultarAgenda() async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _mensagem = 'Consultando os compromissos do celular...';
    });
    try {
      var permissao = await _calendario.hasPermissions();
      if (permissao.data != true) {
        permissao = await _calendario.requestPermissions();
      }
      if (permissao.data != true) {
        if (!mounted) return;
        setState(() {
          _autorizado = false;
          _mensagem =
              'Permissão de agenda não concedida. Você pode tentar novamente.';
        });
        return;
      }

      final agora = DateTime.now();
      final fim = agora.add(const Duration(days: 7));
      final resultadoCalendarios = await _calendario.retrieveCalendars();
      if (!resultadoCalendarios.isSuccess) {
        throw Exception('Não foi possível consultar os calendários.');
      }
      final eventos = <Event>[];
      for (final calendario in resultadoCalendarios.data ?? <Calendar>[]) {
        if (calendario.id == null) continue;
        final resposta = await _calendario.retrieveEvents(
          calendario.id,
          RetrieveEventsParams(startDate: agora, endDate: fim),
        );
        if (!resposta.isSuccess) continue;
        eventos.addAll(
          (resposta.data ?? <Event>[]).where((evento) {
            final inicio = evento.start;
            final termino = evento.end;
            if (evento.allDay == true || inicio == null) return false;
            return inicio.isAfter(agora) ||
                (termino != null && termino.isAfter(agora));
          }),
        );
      }
      eventos.sort((a, b) => a.start!.compareTo(b.start!));
      final unicos = <String, Event>{};
      for (final evento in eventos) {
        final chave =
            '${evento.eventId ?? evento.title}-${evento.start?.millisecondsSinceEpoch}';
        unicos.putIfAbsent(chave, () => evento);
      }
      if (!mounted) return;
      setState(() {
        _autorizado = true;
        _eventos = unicos.values.take(30).toList();
        _mensagem = _eventos.isEmpty
            ? 'Nenhum compromisso com horário encontrado nos próximos 7 dias.'
            : '${_eventos.length} compromisso(s) encontrado(s) nos próximos 7 dias.';
      });
      await _carregarDuracaoHistorica();
    } catch (erro) {
      if (!mounted) return;
      setState(() => _mensagem = 'Não foi possível ler a agenda: $erro');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _analisarRisco() async {
    if (_analisandoRisco) return;

    setState(() {
      _analisandoRisco = true;
      _avisoModelo = 'Consultando o modelo ANHANGÁ...';
    });

    try {
      final resposta = await Supabase.instance.client.functions.invoke(
        'prever-sessao',
        body: {
          'duracao_atual': _duracaoAtual,
          'limite_minutos': _limiteMinutos,
          'media_historica': _duracaoHabitual.toDouble(),
          'pausas': _pausas,
        },
      );

      final dados = Map<String, dynamic>.from(resposta.data as Map);
      final resultado = Map<String, dynamic>.from(dados['resultado'] as Map);

      if (!mounted) return;

      setState(() {
        _pontuacaoModelo = (resultado['pontuacao_modelo'] as num).toDouble();
        _classificacaoModelo = resultado['classificacao_modelo'].toString();

        _avisoModelo =
            'Modelo experimental treinado com dados sintéticos. '
            'A pontuação não é uma probabilidade validada '
            'do comportamento real.';
      });
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        _pontuacaoModelo = null;
        _avisoModelo = 'Não foi possível consultar o modelo: $erro';
      });
    } finally {
      if (mounted) {
        setState(() => _analisandoRisco = false);
      }
    }
  }

  String _recomendacao() {
    if (!_autorizado) {
      return 'Autorize a consulta à agenda para receber recomendações.';
    }
    if (_eventos.isEmpty) {
      return 'Não há compromissos próximos registrados. Respeite seu limite de jogo e faça pausas.';
    }
    final agora = DateTime.now();
    final proximo = _eventos.first;
    final inicio = horarioLocalAgenda(proximo.start!);
    final minutos = inicio.difference(agora).inMinutes;
    final tempoLivre = minutos - _minutosParaPreparacao;
    if (tempoLivre <= 0) {
      return 'Seu compromisso está próximo. Recomendo encerrar o jogo agora para se preparar.';
    }
    if (tempoLivre < _limiteEscolhido) {
      return 'Você tem cerca de $tempoLivre min disponíveis antes de se preparar. Suas partidas duram em média $_duracaoHabitual min; considere jogar por menos tempo ou encerrar a sessão atual.';
    }
    final prazo = inicio.subtract(Duration(minutes: _minutosParaPreparacao));
    return 'Você pode planejar uma sessão, mas recomendo encerrar até ${_hora(prazo)} para ter $_minutosParaPreparacao min de preparação.';
  }

  @override
  Widget build(BuildContext context) {
    final proximo = _eventos.isEmpty ? null : _eventos.first;
    final agora = DateTime.now();
    final prazo = proximo?.start == null
        ? null
        : horarioLocalAgenda(proximo!.start!)
              .subtract(Duration(minutes: _minutosParaPreparacao));
    final restantes = prazo == null
        ? null
        : math.max(0, prazo.difference(agora).inMinutes);
    return Scaffold(
      appBar: AppBar(title: const Text('Agenda Inteligente')),
      body: RefreshIndicator(
        onRefresh: _consultarAgenda,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'ANHANGÁ • Planeje seu tempo de jogo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
            const SizedBox(height: 10),
            const Text(
              'Com sua permissão, o ANHANGÁ consulta os próximos compromissos do celular. '
              'Os eventos não são enviados ao banco de dados nem modificados.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _ocupado ? null : _consultarAgenda,
              icon: Icon(_ocupado ? Icons.hourglass_top : Icons.calendar_month),
              label: Text(
                _ocupado ? 'Consultando...' : 'Consultar minha agenda',
              ),
            ),
            const SizedBox(height: 8),
            Text(_mensagem),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Meu planejamento',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tempo de preparação: $_minutosParaPreparacao minutos',
                    ),
                    Slider(
                      min: 5,
                      max: 60,
                      divisions: 11,
                      value: _minutosParaPreparacao.toDouble(),
                      label: '$_minutosParaPreparacao min',
                      onChanged: (valor) => setState(
                        () => _minutosParaPreparacao = valor.round(),
                      ),
                    ),
                    Text(
                      'Duração habitual da partida: $_duracaoHabitual minutos',
                    ),
                    Text(
                      _historicoDisponivel
                          ? 'Estimativa baseada nas últimas sessões disponíveis no seu histórico.'
                          : 'Estimativa padrão. Histórico de partidas indisponível.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _limiteCarregado
                          ? 'Seu limite definido no Meu Ritmo: $_limiteEscolhido minutos'
                          : 'Limite de referência: $_limiteEscolhido minutos',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_recomendacao()),
                    const SizedBox(height: 24),
                    const Text(
                      'Análise inteligente da sessão',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Informe os valores da sessão para simular '
                      'uma previsão do modelo existente.',
                    ),
                    const SizedBox(height: 12),
                    Text('Tempo jogado: ${_duracaoAtual.round()} minutos'),
                    Slider(
                      value: _duracaoAtual,
                      min: 0,
                      max: 240,
                      divisions: 48,
                      onChanged: (valor) => setState(() {
                        _duracaoAtual = valor;
                        _pontuacaoModelo = null;
                      }),
                    ),
                    Text('Limite escolhido: ${_limiteMinutos.round()} minutos'),
                    Slider(
                      value: _limiteMinutos,
                      min: 15,
                      max: 240,
                      divisions: 15,
                      onChanged: (valor) => setState(() {
                        _limiteMinutos = valor;
                        _pontuacaoModelo = null;
                      }),
                    ),
                    Text('Pausas realizadas: $_pausas'),
                    Slider(
                      value: _pausas.toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      onChanged: (valor) => setState(() {
                        _pausas = valor.round();
                        _pontuacaoModelo = null;
                      }),
                    ),
                    FilledButton.icon(
                      onPressed: _analisandoRisco ? null : _analisarRisco,
                      icon: const Icon(Icons.psychology),
                      label: Text(
                        _analisandoRisco
                            ? 'Analisando...'
                            : 'Analisar minha sessão',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_pontuacaoModelo != null) ...[
                      Text(
                        'Pontuação do modelo: '
                        '${_pontuacaoModelo!.toStringAsFixed(1)}%',
                      ),
                      Text(
                        _classificacaoModelo == 'risco_elevado'
                            ? 'Classificação: risco elevado'
                            : 'Classificação: abaixo do limiar',
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(_avisoModelo),
                    if (restantes != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Tempo disponível até começar a se preparar: $restantes min',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Próximos compromissos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_eventos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Nenhum compromisso carregado.'),
              ),
            for (final evento in _eventos)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(
                    (evento.title ?? '').trim().isEmpty
                        ? 'Compromisso sem título'
                        : evento.title!,
                  ),
                  subtitle: Text(
                    '${_data(horarioLocalAgenda(evento.start!))} às ${_hora(horarioLocalAgenda(evento.start!))}',
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              'As recomendações desta versão usam regras de horário e média histórica; '
              'não representam uma nova previsão do modelo de Machine Learning.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
