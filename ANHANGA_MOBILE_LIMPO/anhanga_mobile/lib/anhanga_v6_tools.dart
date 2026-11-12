import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reconhecimento de voz em português. Apenas preenche a pergunta no chat;
/// o jogador continua escolhendo quando enviar ao Gemini.
class AnHangaVozV6 extends StatefulWidget {
  const AnHangaVozV6({
    super.key,
    required this.onRecognized,
    this.enabled = true,
  });
  final ValueChanged<String> onRecognized;
  final bool enabled;

  @override
  State<AnHangaVozV6> createState() => _AnHangaVozV6State();
}

class _AnHangaVozV6State extends State<AnHangaVozV6> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _escutando = false;
  bool _iniciando = false;

  Future<void> _alternar() async {
    if (_iniciando || !widget.enabled) return;
    if (_speech.isListening) {
      await _speech.stop();
      if (mounted) setState(() => _escutando = false);
      return;
    }
    setState(() => _iniciando = true);
    try {
      final disponivel = await _speech.initialize(
        onStatus: (status) {
          if (mounted) setState(() => _escutando = status == 'listening');
        },
        onError: (_) {
          if (mounted) setState(() => _escutando = false);
        },
      );
      if (!disponivel) {
        if (mounted) {
          _mensagem(
            'Reconhecimento de voz não disponível. Verifique a permissão do microfone.',
          );
        }
        return;
      }
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: 'pt_BR',
          partialResults: false,
        ),
        onResult: (resultado) {
          if (resultado.finalResult && mounted && widget.enabled) {
            final texto = resultado.recognizedWords.trim();
            if (texto.isNotEmpty) widget.onRecognized(texto);
          }
        },
      );
      if (mounted) setState(() => _escutando = true);
    } catch (_) {
      if (mounted) _mensagem('Não foi possível ativar o microfone.');
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  void _mensagem(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _escutando ? 'Parar microfone' : 'Ditado por voz (português)',
    onPressed: widget.enabled && !_iniciando ? _alternar : null,
    icon: Icon(
      _escutando ? Icons.mic : Icons.mic_none,
      color: _escutando ? Colors.redAccent : null,
    ),
  );
}

/// Exporta um retrato dos registros que o usuário autenticado pode ler.
/// Não envia PDF ou chave de API ao Gemini.
class AnHangaPdfV6 extends StatefulWidget {
  const AnHangaPdfV6({super.key});

  @override
  State<AnHangaPdfV6> createState() => _AnHangaPdfV6State();
}

class _AnHangaPdfV6State extends State<AnHangaPdfV6> {
  bool _gerando = false;
  double _numero(Object? n) =>
      n is num ? n.toDouble() : double.tryParse('$n') ?? 0;
  String _duracao(double m) => '${(m / 60).toStringAsFixed(1)} h';

  Future<void> _gerar() async {
    if (_gerando) return;
    setState(() => _gerando = true);
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw StateError('Faça login para gerar o relatório.');
      final perfil = await client
          .from('dim_usuario')
          .select('id_usuario')
          .eq('auth_user_id', uid)
          .maybeSingle();
      if (perfil == null) throw StateError('Perfil de jogador não encontrado.');
      final dados = await client
          .from('fato_ia')
          .select(
            'id_jogo,nome_jogo_original,inicio,plataforma,duracao_minutos,quantidade_pausas,classificacao',
          )
          .eq('id_usuario', perfil['id_usuario'])
          .order('inicio', ascending: false)
          .limit(500);
      final catalogo = await client
          .from('dim_jogo')
          .select('id_jogo,nome_jogo');
      if (client.auth.currentUser?.id != uid) {
        throw StateError('Conta alterada. Faça login novamente.');
      }
      final nomes = <String, String>{};
      for (final linha in catalogo) {
        final nome = (linha['nome_jogo'] as String?)?.trim() ?? '';
        if (linha['id_jogo'] != null && nome.isNotEmpty) {
          nomes['${linha['id_jogo']}'] = nome;
        }
      }
      final jogos = <String, double>{};
      final classificacoes = <String, int>{};
      final plataformas = <String, double>{};
      double totalMin = 0, semNomeMin = 0;
      int pausas = 0, semNome = 0;
      for (final p in dados) {
        final min = _numero(p['duracao_minutos']).clamp(0.0, 1440.0).toDouble();
        totalMin += min;
        pausas += _numero(p['quantidade_pausas'])
            .toInt()
            .clamp(0, 10000)
            .toInt();
        final id = p['id_jogo']?.toString();
        final nome =
            (id == null ? null : nomes[id]) ??
            (p['nome_jogo_original'] as String?)?.trim() ??
            '';
        if (nome.isEmpty) {
          semNome++;
          semNomeMin += min;
        } else {
          jogos[nome] = (jogos[nome] ?? 0) + min;
        }
        final plataforma = (p['plataforma'] as String?)?.trim();
        final chave = plataforma == null || plataforma.isEmpty
            ? 'Não identificada'
            : plataforma;
        plataformas[chave] = (plataformas[chave] ?? 0) + min;
        final c = p['classificacao']?.toString() ?? 'Sem classificação';
        classificacoes[c] = (classificacoes[c] ?? 0) + 1;
      }
      final ordenados = jogos.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final pdf = pw.Document(title: 'ANHANGA - Relatorio de jogos');
      final agora = DateTime.now();
      final periodo = dados.isEmpty
          ? 'Sem sessões no recorte'
          : 'Amostra de até 500 sessões mais recentes';
      final azul = PdfColor.fromHex('#1A3666');
      final verde = PdfColor.fromHex('#17A460');
      pw.Widget grafico(String nome, List<MapEntry<String, double>> itens) {
        final maximo = itens.isEmpty
            ? 1.0
            : itens.first.value.clamp(1.0, 1e9).toDouble();
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              nome,
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: azul,
              ),
            ),
            pw.SizedBox(height: 8),
            for (final item in itens.take(8)) ...[
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      item.key,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Container(
                        width:
                            130.0 *
                            (item.value / maximo).clamp(0.0, 1.0).toDouble(),
                        height: 8,
                        color: verde,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(
                    width: 48,
                    child: pw.Text(
                      _duracao(item.value),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
            ],
          ],
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) => [
            pw.Text(
              'NOVERIS | ANHANGÁ',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: azul,
              ),
            ),
            pw.Text(
              'Relatório de sessões e jogos',
              style: const pw.TextStyle(fontSize: 16),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Gerado em ${agora.day}/${agora.month}/${agora.year} • $periodo',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Divider(),
            pw.Text(
              'Partidas: ${dados.length}     Tempo: ${_duracao(totalMin)}     Pausas: $pausas',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Média por partida: ${dados.isEmpty ? '0' : (totalMin / dados.length).toStringAsFixed(1)} minutos',
            ),
            pw.SizedBox(height: 18),
            grafico('Ranking por tempo jogado', ordenados),
            pw.SizedBox(height: 14),
            pw.Text(
              'Sessões sem jogo identificado: $semNome (${_duracao(semNomeMin)}). Não entram no ranking.',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 18),
            grafico(
              'Tempo por plataforma',
              (plataformas.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value))),
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Classificações registradas',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: azul,
              ),
            ),
            for (final c in classificacoes.entries)
              pw.Text('${c.key}: ${c.value}'),
            pw.SizedBox(height: 18),
            pw.Text(
              'Limites: relatório baseado nas sessões recentes visíveis ao jogador. As classificações podem vir de modelo experimental e não são diagnósticos.',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      );
      final Uint8List bytes = await pdf.save();
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'ANHANGA_relatorio_${agora.year}_${agora.month}_${agora.day}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message
                  : 'Não foi possível gerar o PDF. Verifique a conexão.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Exportar relatório PDF',
    onPressed: _gerando ? null : _gerar,
    icon: _gerando
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.picture_as_pdf),
  );
}

/// Temporizador voluntário de sessão na tela. Não executa em segundo plano;
/// não monitora sessões do timer principal sem integração específica.
class AnHangaAlertaV6 extends StatefulWidget {
  const AnHangaAlertaV6({super.key});
  @override
  State<AnHangaAlertaV6> createState() => _AnHangaAlertaV6State();
}

class _AnHangaAlertaV6State extends State<AnHangaAlertaV6> {
  Timer? _ticker;
  DateTime? _inicio;
  Duration _acumulado = Duration.zero;
  int _limite = 60;
  bool _avisoEnviado = false;
  bool _finalEnviado = false;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarLimite();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _atualizar());
  }

  Future<void> _carregarLimite() async {
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid != null) {
        final p = await client
            .from('dim_usuario')
            .select('limite_minutos_sessao')
            .eq('auth_user_id', uid)
            .maybeSingle();
        final valor = (p?['limite_minutos_sessao'] as num?)?.round();
        if (mounted && valor != null && valor >= 1 && valor <= 1440) {
          setState(() => _limite = valor);
        }
      }
    } catch (_) {
      // Padrão ajustável manualmente caso preferências não estejam disponíveis.
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Duration get _decorrido =>
      _acumulado +
      (_inicio == null ? Duration.zero : DateTime.now().difference(_inicio!));

  void _atualizar() {
    if (!mounted || _inicio == null) return;
    final minutos = _decorrido.inSeconds;
    final segundosLimite = _limite * 60;
    if (!_avisoEnviado &&
        minutos >= (segundosLimite - 300).clamp(0, segundosLimite)) {
      _avisoEnviado = true;
      _mostrar(
        'Faltam até 5 minutos para seu limite de $_limite min. Que tal planejar uma pausa?',
      );
    }
    if (!_finalEnviado && minutos >= segundosLimite) {
      _finalEnviado = true;
      _mostrar(
        'Você atingiu seu limite de $_limite min. Considere fazer uma pausa.',
      );
    }
    setState(() {});
  }

  void _mostrar(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), duration: const Duration(seconds: 7)),
    );
  }

  void _iniciarOuPausar() {
    setState(() {
      if (_inicio == null) {
        _inicio = DateTime.now();
      } else {
        _acumulado = _decorrido;
        _inicio = null;
      }
    });
  }

  void _reiniciar() {
    setState(() {
      _inicio = null;
      _acumulado = Duration.zero;
      _avisoEnviado = false;
      _finalEnviado = false;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duracao = _decorrido;
    final h = duracao.inHours.toString().padLeft(2, '0');
    final m = (duracao.inMinutes % 60).toString().padLeft(2, '0');
    final s = (duracao.inSeconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(title: const Text('Alerta de sessão V6')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Temporizador do Chat IA',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Este temporizador avisa enquanto esta tela estiver aberta. Não envia notificações se o app estiver fechado ou em segundo plano.',
          ),
          const SizedBox(height: 30),
          Center(
            child: Text(
              '$h:$m:$s',
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Limite da sessão: $_limite minutos${_carregando ? ' (carregando preferência...)' : ''}',
          ),
          Slider(
            min: 1,
            max: 180,
            divisions: 179,
            value: _limite.clamp(1, 180).toDouble(),
            label: '$_limite min',
            onChanged: _inicio == null && _acumulado == Duration.zero
                ? (v) => setState(() => _limite = v.round())
                : null,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _iniciarOuPausar,
            icon: Icon(_inicio == null ? Icons.play_arrow : Icons.pause),
            label: Text(_inicio == null ? 'Iniciar / continuar' : 'Pausar'),
          ),
          OutlinedButton(
            onPressed: _reiniciar,
            child: const Text('Reiniciar cronômetro'),
          ),
          const SizedBox(height: 14),
          const Text(
            'O alerta aparece até 5 minutos antes do limite e novamente ao atingir o limite. Não altera o histórico de partidas.',
          ),
        ],
      ),
    );
  }
}
