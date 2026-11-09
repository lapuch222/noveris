import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'graficos_anhanga.dart';

// ============================================================
// CONFIGURAÇÃO SUPABASE
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://wkfujrfuederxdqjotqj.supabase.co',
    publishableKey: 'sb_publishable_g7shyNcyFgyvNJYs0bHJBQ_kImp4quN',
  );

  runApp(const AnhangaApp());
}

final supabase = Supabase.instance.client;

// Apresentacao em portugues brasileiro (os dados no banco nao mudam).
String formatarDuracao(num? valor) {
  if (valor == null) return '—';
  final total = valor.round();
  final horas = total ~/ 60;
  final minutos = total % 60;
  return horas == 0
      ? '${minutos}min'
      : '${horas}h ${minutos.toString().padLeft(2, '0')}min';
}

String formatarDataBR(Object? valor) {
  if (valor == null || valor.toString().isEmpty) return 'Não informado';
  final data = DateTime.tryParse(valor.toString())?.toLocal();
  if (data == null) return 'Data inválida';
  String d(int n) => n.toString().padLeft(2, '0');
  return '${d(data.day)}/${d(data.month)}/${data.year} às ${d(data.hour)}:${d(data.minute)}';
}

String formatarNumeroBR(num valor, {int casas = 1}) =>
    valor.toStringAsFixed(casas).replaceAll('.', ',');

// ============================================================
// APLICATIVO PRINCIPAL
// ============================================================

class AnhangaApp extends StatelessWidget {
  const AnhangaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANHANGÁ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF04090D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5FD4EC),
          brightness: Brightness.dark,
        ),
      ),
      home: const AnhangaInicial(),
    );
  }
}

// ============================================================
// ABERTURA E AUTENTICAÇÃO
// ============================================================

class AnhangaInicial extends StatefulWidget {
  const AnhangaInicial({super.key});

  @override
  State<AnhangaInicial> createState() => _AnhangaInicialState();
}

class _AnhangaInicialState extends State<AnhangaInicial> {
  bool abertura = true;

  late final StreamSubscription<AuthState> authSubscription;
  Timer? timer;

  @override
  void initState() {
    super.initState();

    authSubscription = supabase.auth.onAuthStateChange.listen((event) {
      if (mounted) setState(() {});
    });

    timer = Timer(const Duration(seconds: 4), fecharAbertura);
  }

  void fecharAbertura() {
    if (!mounted) {
      return;
    }

    timer?.cancel();

    setState(() {
      abertura = false;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (abertura) {
      return AnhangaAbertura(onEntrar: fecharAbertura);
    }

    if (supabase.auth.currentSession == null) {
      return const AnhangaLogin();
    }

    return const AnhangaPainel();
  }
}

// ============================================================
// CERVO ORIGINAL ANIMADO
// ============================================================

class AnhangaAbertura extends StatefulWidget {
  const AnhangaAbertura({super.key, required this.onEntrar});

  final VoidCallback onEntrar;

  @override
  State<AnhangaAbertura> createState() => _AnhangaAberturaState();
}

class _AnhangaAberturaState extends State<AnhangaAbertura>
    with SingleTickerProviderStateMixin {
  late AnimationController animacao;

  @override
  void initState() {
    super.initState();

    animacao = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
    )..repeat();
  }

  @override
  void dispose() {
    animacao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04090D),
      body: InkWell(
        onTap: widget.onEntrar,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final lado = math.min(
                constraints.maxWidth * 0.93,
                constraints.maxHeight * 0.65,
              );

              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: lado,
                      height: lado,
                      child: AnimatedBuilder(
                        animation: animacao,
                        builder: (context, child) {
                          final pulso =
                              0.5 -
                              0.5 * math.cos(2 * math.pi * animacao.value);

                          return Stack(
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/images/anhanga_logo.webp',
                                  fit: BoxFit.fill,
                                ),
                              ),
                              Positioned(
                                left: lado * 0.319,
                                top: lado * (0.1555 - 0.006 * pulso),
                                width: lado * 0.331,
                                height: lado * 0.59,
                                child: Opacity(
                                  opacity: 0.86 + 0.14 * pulso,
                                  child: Transform.scale(
                                    scale: 1 + 0.009 * pulso,
                                    alignment: Alignment.bottomCenter,
                                    child: Image.asset(
                                      'assets/images/anhanga_cervo.webp',
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'TOQUE PARA CONTINUAR',
                      style: TextStyle(
                        color: Color(0xFF8FB0BB),
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LOGIN E CADASTRO
// ============================================================

class AnhangaLogin extends StatefulWidget {
  const AnhangaLogin({super.key});

  @override
  State<AnhangaLogin> createState() => _AnhangaLoginState();
}

class _AnhangaLoginState extends State<AnhangaLogin> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  bool cadastro = false;
  bool carregando = false;
  String mensagem = '';

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  Future<void> autenticar() async {
    if (carregando) return;

    setState(() {
      carregando = true;
      mensagem = '';
    });

    try {
      final email = emailController.text.trim();
      final senha = senhaController.text;

      if (email.isEmpty || senha.isEmpty) {
        throw const AuthException('Preencha o e-mail e a senha.');
      }

      if (cadastro) {
        final resposta = await supabase.auth.signUp(
          email: email,
          password: senha,
        );

        if (resposta.session == null && mounted) {
          setState(() {
            mensagem =
                'Cadastro realizado. Verifique seu e-mail '
                'para confirmar a conta, se solicitado.';
          });
        }
      } else {
        await supabase.auth.signInWithPassword(email: email, password: senha);
      }
    } on AuthException catch (erro) {
      if (mounted) {
        setState(() => mensagem = erro.message);
      }
    } catch (erro) {
      if (mounted) {
        setState(() {
          mensagem = 'Erro ao autenticar: $erro';
        });
      }
    } finally {
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  Future<void> entrarGoogle() async {
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.noveris.anhanga_mobile://login-callback/',
      );
    } catch (erro) {
      if (mounted) {
        setState(() {
          mensagem = 'Não foi possível entrar com Google: $erro';
        });
      }
    }
  }

  Future<void> recuperarSenha() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        mensagem = 'Digite seu e-mail primeiro.';
      });
      return;
    }

    try {
      await supabase.auth.resetPasswordForEmail(email);

      if (mounted) {
        setState(() {
          mensagem =
              'Se o e-mail estiver cadastrado, você receberá '
              'instruções de recuperação.';
        });
      }
    } catch (erro) {
      if (mounted) {
        setState(() {
          mensagem = 'Erro: $erro';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const azul = Color(0xFF5FD4EC);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/anhanga_cervo.webp', height: 150),
                  const SizedBox(height: 16),
                  const Text(
                    'ANHANGÁ',
                    style: TextStyle(
                      color: azul,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    cadastro ? 'Criar minha conta' : 'Entrar na minha conta',
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: senhaController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: carregando ? null : autenticar,
                    child: Text(cadastro ? 'Criar conta' : 'Entrar'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: entrarGoogle,
                    icon: const Icon(Icons.account_circle),
                    label: const Text('Entrar com Google'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        cadastro = !cadastro;
                        mensagem = '';
                      });
                    },
                    child: Text(
                      cadastro ? 'Já tenho conta' : 'Criar uma conta',
                    ),
                  ),
                  TextButton(
                    onPressed: recuperarSenha,
                    child: const Text('Esqueci minha senha'),
                  ),
                  if (carregando) const CircularProgressIndicator(),
                  if (mensagem.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        mensagem,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: azul),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PAINEL E DADOS DO SUPABASE
// ============================================================

class AnhangaPainel extends StatefulWidget {
  const AnhangaPainel({super.key});

  @override
  State<AnhangaPainel> createState() => _AnhangaPainelState();
}

class _AnhangaPainelState extends State<AnhangaPainel> {
  int pagina = 0;

  bool carregando = true;
  bool altoContraste = false;

  String paleta = 'Padrão';
  String? erro;

  List<Map<String, dynamic>> sessoes = [];
  List<Map<String, String>> jogosInstalados = [];
  bool carregandoJogos = false;
  String? erroJogos;
  String? jogoSelecionado;
  int limiteSessao = 60;
  final horasController = TextEditingController(text: '1');
  final minutosController = TextEditingController(text: '0');
  String? erroTempo;
  int periodoDias = 0; // 0 = todo o histórico disponível

  static const canalJogos = MethodChannel('com.noveris.anhanga_mobile/jogos');

  int totalSessoes = 0;
  int totalMinutos = 0;
  int totalPausas = 0;
  double duracaoMedia = 0;

  static const azul = Color(0xFF5FD4EC);

  @override
  void initState() {
    super.initState();
    carregarDados();
    carregarJogos();
  }

  @override
  void dispose() {
    horasController.dispose();
    minutosController.dispose();
    super.dispose();
  }

  void definirTempoManual() {
    final horas = int.tryParse(horasController.text.trim());
    final minutos = int.tryParse(minutosController.text.trim());
    if (horas == null || minutos == null || horas < 0 || horas > 23 ||
        minutos < 0 || minutos > 59 || (horas == 0 && minutos == 0)) {
      setState(() => erroTempo =
          'Informe de 0 a 23 horas e de 0 a 59 minutos. O tempo deve ser maior que zero.');
      return;
    }
    setState(() {
      limiteSessao = horas * 60 + minutos;
      erroTempo = null;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> carregarJogos() async {
    if (!mounted) {
      return;
    }
    setState(() {
      carregandoJogos = true;
      erroJogos = null;
    });
    try {
      final resposta = await canalJogos.invokeMethod<List<dynamic>>(
        'listarJogos',
      );
      final jogos = (resposta ?? []).map((item) {
        final mapa = Map<dynamic, dynamic>.from(item as Map);
        return <String, String>{
          'nome': mapa['nome']?.toString() ?? 'Jogo sem nome',
          'pacote': mapa['pacote']?.toString() ?? '',
        };
      }).toList();
      if (mounted) {
        setState(() => jogosInstalados = jogos);
      }
    } on MissingPluginException {
      if (mounted) {
        setState(
          () => erroJogos = 'Integração Android não encontrada. Verifique o MainActivity.kt e reinicie o aplicativo.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => erroJogos = 'Não foi possível consultar os jogos: $e');
      }
    } finally {
      if (mounted) {
        setState(() => carregandoJogos = false);
      }
    }
  }

  int inteiro(dynamic valor) {
    if (valor is num) return valor.toInt();

    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  double decimal(dynamic valor) {
    if (valor is num) return valor.toDouble();

    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }

  // Consulta somente registros que as políticas RLS
  // do Supabase permitirem à conta autenticada.
  //
  // IMPORTANTE: a associação entre auth.users e
  // dim_usuario ainda precisa ser verificada no banco.

  Future<void> carregarDados() async {
    if (!mounted) {
      return;
    }

    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      if (supabase.auth.currentSession == null) {
        throw Exception('Usuário não autenticado.');
      }

      final resposta = await supabase
          .from('fato_ia')
          .select(
            'id_fato, id_usuario, duracao_minutos, '
            'quantidade_pausas, plataforma, classificacao, '
            'score_anomalia, score_contexto, '
            'duracao_prevista, probabilidade_prolongada, '
            'recomendacao, inicio',
          )
          .order('id_fato', ascending: false)
          .limit(1000);

      final registros = List<Map<String, dynamic>>.from(resposta);

      int minutos = 0;
      int pausas = 0;

      for (final sessao in registros) {
        minutos += inteiro(sessao['duracao_minutos']);
        pausas += inteiro(sessao['quantidade_pausas']);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        sessoes = registros;

        totalSessoes = registros.length;
        totalMinutos = minutos;
        totalPausas = pausas;

        duracaoMedia = registros.isEmpty ? 0 : minutos / registros.length;

        carregando = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        carregando = false;
        erro = e.toString();

        sessoes = [];
        totalSessoes = 0;
        totalMinutos = 0;
        totalPausas = 0;
        duracaoMedia = 0;
      });
    }
  }

  Color get destaque {
    if (altoContraste) {
      return Colors.yellow;
    }

    switch (paleta) {
      case 'Protanopia':
        return const Color(0xFF5AA9FF);
      case 'Deuteranopia':
        return const Color(0xFFE69F00);
      case 'Tritanopia':
        return const Color(0xFFFF7A6B);
      case 'Acromatopsia':
        return Colors.white;
      default:
        return azul;
    }
  }

  Widget cartao(String titulo, Widget conteudo) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: altoContraste ? Colors.black : const Color(0xFF0A1720),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: altoContraste ? Colors.white : const Color(0xFF1B3B4A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: destaque,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          conteudo,
        ],
      ),
    );
  }

  Widget indicador(String titulo, String valor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF102431),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valor,
              style: TextStyle(
                color: destaque,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(titulo),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // TELA PAINEL
  // ==========================================================

  List<Map<String, dynamic>> get sessoesPeriodo {
    if (periodoDias == 0) return sessoes;
    final inicio = DateTime.now().subtract(Duration(days: periodoDias));
    return sessoes.where((sessao) {
      final data = DateTime.tryParse(sessao['inicio']?.toString() ?? '');
      return data != null && !data.toLocal().isBefore(inicio);
    }).toList();
  }

  Widget filtrosDashboard() => cartao(
    'Filtros dos gráficos',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          initialValue: periodoDias,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Período',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 0,
              child: Text('Todo o histórico disponível'),
            ),
            DropdownMenuItem(value: 7, child: Text('Últimos 7 dias')),
            DropdownMenuItem(value: 30, child: Text('Últimos 30 dias')),
            DropdownMenuItem(value: 90, child: Text('Últimos 90 dias')),
          ],
          onChanged: (valor) {
            if (valor != null) setState(() => periodoDias = valor);
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Sessões no período: ${sessoesPeriodo.length} • ${formatarDuracao(minutosPeriodo)} no total',
        ),
        const Text(
          'Os gráficos mostram as sessões acessíveis no Supabase. A filtragem por jogo dependerá de vincular cada sessão ao jogo.',
        ),
      ],
    ),
  );

  String get descricaoPeriodo =>
      periodoDias == 0 ? 'Todo o histórico' : 'Últimos $periodoDias dias';

  int get minutosPeriodo => sessoesPeriodo.fold<int>(
    0,
    (soma, sessao) => soma + inteiro(sessao['duracao_minutos']),
  );

  int get pausasPeriodo => sessoesPeriodo.fold<int>(
    0,
    (soma, sessao) => soma + inteiro(sessao['quantidade_pausas']),
  );

  double get mediaPeriodo =>
      sessoesPeriodo.isEmpty ? 0 : minutosPeriodo / sessoesPeriodo.length;

  Widget telaPainel() {
    return Column(
      children: [
        cartao(
          'Bem-vindo ao ANHANGÁ',
          const Text(
            'Análise Neural de Hábitos, Ambiente '
            'e Gaming Adaptativo.\n\n'
            'Seu assistente inteligente para sessões de jogos.',
          ),
        ),
        filtrosDashboard(),
        cartao(
          'Resumo das sessões • $descricaoPeriodo',
          Column(
            children: [
              Row(
                children: [
                  indicador('Sessões', '${sessoesPeriodo.length}'),
                  const SizedBox(width: 10),
                  indicador('Tempo total', formatarDuracao(minutosPeriodo)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  indicador('Pausas', '$pausasPeriodo'),
                  const SizedBox(width: 10),
                  indicador('Média', formatarDuracao(mediaPeriodo)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Indicadores calculados a partir dos '
                'registros retornados pelo Supabase.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        cartao('Duração das últimas sessões', graficoSessoes()),
        cartao('Tempo jogado em cada sessão', graficoBarras()),
        cartao('Evolução do tempo de jogo', graficoLinhas()),
        cartao('Sessões com e sem pausas', graficoRosca()),
        cartao(
          'Inteligência artificial',
          const Text(
            'Acesse a aba Análise para visualizar '
            'os resultados registrados das sessões.\n\n'
            'A previsão de novas sessões pela Edge Function '
            'será integrada posteriormente.',
          ),
        ),
      ],
    );
  }

  List<PontoSessao> get pontosRecentes =>
      sessoesPeriodo.take(7).map(PontoSessao.deMapa).toList().reversed.toList();

  PaletaGraficos get paletaDosGraficos => PaletaGraficos.de(
    paleta: paleta,
    altoContraste: altoContraste,
    destaque: destaque,
  );

  Widget graficoSessoes() => GraficoHorizontalSessoes(
    pontos: pontosRecentes,
    paleta: paletaDosGraficos,
    periodo: descricaoPeriodo,
    limite: limiteSessao.toDouble(),
  );

  Widget graficoBarras() => GraficoCartesianoSessoes(
    pontos: pontosRecentes,
    paleta: paletaDosGraficos,
    periodo: descricaoPeriodo,
    linhas: false,
    limite: limiteSessao.toDouble(),
  );

  // Um ponto por dia: soma das durações das sessões daquele dia.
  // Evita datas repetidas e permite acompanhar a evolução diária real.
  List<PontoSessao> get pontosPorDia {
    final totais = <DateTime, double>{};
    for (final sessao in sessoesPeriodo) {
      final data = DateTime.tryParse(sessao['inicio']?.toString() ?? '')?.toLocal();
      if (data == null) continue;
      final dia = DateTime(data.year, data.month, data.day);
      totais[dia] = (totais[dia] ?? 0) + decimal(sessao['duracao_minutos']);
    }
    final dias = totais.keys.toList()..sort();
    return dias.reversed.take(7).toList().reversed.map((dia) => PontoSessao(
      id: 0,
      minutos: totais[dia]!,
      inicio: dia,
    )).toList();
  }

  Widget graficoLinhas() => GraficoCartesianoSessoes(
    pontos: pontosPorDia,
    paleta: paletaDosGraficos,
    periodo: descricaoPeriodo,
    linhas: true,
    // Limite é por sessão, portanto não é comparável ao total do dia.
    limite: null,
  );

  Widget graficoRosca() {
    final dados = sessoesPeriodo;
    final comPausas = dados.where((s) => inteiro(s['quantidade_pausas']) > 0).length;
    return GraficoRoscaPausas(
      comPausas: comPausas,
      semPausas: dados.length - comPausas,
      paleta: paletaDosGraficos,
      periodo: descricaoPeriodo,
    );
  }

  // ==========================================================
  // TELA JOGOS
  // ==========================================================

  Widget telaJogos() {
    return cartao(
      'Biblioteca de jogos instalados',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Jogos identificados no Android. A lista pode ser limitada pelas regras de visibilidade do sistema.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: carregandoJogos ? null : carregarJogos,
            icon: const Icon(Icons.refresh),
            label: const Text('Buscar jogos'),
          ),
          if (carregandoJogos) const LinearProgressIndicator(),
          if (erroJogos != null)
            Text(
              erroJogos!,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          if (!carregandoJogos && erroJogos == null && jogosInstalados.isEmpty)
            const Text('Nenhum jogo visível foi identificado.'),
          if (jogoSelecionado != null) ...[
            const SizedBox(height: 12),
            Text(
              'Jogo selecionado: ${jogosInstalados.where((j) => j['pacote'] == jogoSelecionado).map((j) => j['nome']).firstOrNull ?? jogoSelecionado}',
            ),
            const SizedBox(height: 10),
            const Text(
              'Quanto tempo você deseja jogar?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tempo selecionado: ${formatarDuracao(limiteSessao)}',
              style: TextStyle(
                color: destaque,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Defina o tempo manualmente',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: horasController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Horas',
                      hintText: 'Ex.: 2',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: minutosController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Minutos',
                      hintText: 'Ex.: 30',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (erroTempo != null) ...[
              const SizedBox(height: 8),
              Text(erroTempo!, style: const TextStyle(color: Colors.orangeAccent)),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: definirTempoManual,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Definir meu tempo'),
            ),
            const SizedBox(height: 12),
            const Text(
              'O tempo escolhido ainda não ativa notificações automáticas. '
              'O monitoramento de jogos será integrado ao Android.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
          for (final jogo in jogosInstalados)
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Icon(
                  jogoSelecionado == jogo['pacote']
                      ? Icons.check_circle
                      : Icons.sports_esports_outlined,
                  color: destaque,
                ),
                selected: jogoSelecionado == jogo['pacote'],
                onTap: () => setState(() => jogoSelecionado = jogo['pacote']),
                title: Text(jogo['nome'] ?? 'Jogo'),
                subtitle: Text(jogo['pacote'] ?? ''),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // TELA ANÁLISE
  // ==========================================================

  Widget telaAnalise() {
    if (sessoes.isEmpty) {
      return cartao(
        'Análise inteligente',
        const Text(
          'Nenhuma análise disponível para esta conta '
          'ou nenhuma sessão acessível.',
        ),
      );
    }

    final analisadas = sessoes.where((sessao) {
      return sessao['classificacao'] != null || sessao['recomendacao'] != null;
    }).toList();

    return Column(
      children: [
        cartao(
          'Análise estatística',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sessões consultadas: $totalSessoes'),
              Text('Tempo total: ${formatarDuracao(totalMinutos)}'),
              Text('Média: ${formatarDuracao(duracaoMedia)}'),
              Text('Total de pausas: $totalPausas'),
              const SizedBox(height: 12),
              const Text(
                'Estes resultados são calculados '
                'a partir das sessões retornadas pelo banco.',
              ),
            ],
          ),
        ),
        cartao(
          'Resultados da IA',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sessões com análise registrada: '
                '${analisadas.length}',
              ),
              const SizedBox(height: 12),
              if (analisadas.isEmpty) const Text('Nenhuma análise registrada.'),
              for (final sessao in analisadas.take(10))
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF102431),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sessão #${sessao['id_fato']}',
                        style: TextStyle(
                          color: destaque,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Classificação: '
                        '${sessao['classificacao'] ?? 'Não informada'}',
                      ),
                      Text(
                        'Score de anomalia: '
                        '${sessao['score_anomalia'] ?? '—'}',
                      ),
                      Text(
                        'Score de contexto: '
                        '${sessao['score_contexto'] ?? '—'}',
                      ),
                      Text(
                        'Duração prevista: '
                        '${sessao['duracao_prevista'] == null ? '—' : formatarDuracao(decimal(sessao['duracao_prevista']))}',
                      ),
                      Text(
                        'Probabilidade registrada: '
                        '${sessao['probabilidade_prolongada'] ?? '—'}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Recomendação: '
                        '${sessao['recomendacao'] ?? 'Não disponível'}',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // TELA HISTÓRICO
  // ==========================================================

  Widget telaHistorico() {
    if (sessoes.isEmpty) {
      return cartao(
        'Histórico de sessões',
        const Text('Nenhuma sessão disponível.'),
      );
    }

    return Column(
      children: [
        for (final sessao in sessoes)
          cartao(
            'Sessão #${sessao['id_fato']}',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plataforma: '
                  '${sessao['plataforma'] ?? 'Não informada'}',
                ),
                Text(
                  'Duração: '
                  '${formatarDuracao(inteiro(sessao['duracao_minutos']))}',
                ),
                Text(
                  'Pausas: '
                  '${sessao['quantidade_pausas'] ?? 0}',
                ),
                Text(
                  'Início: '
                  '${formatarDataBR(sessao['inicio'])}',
                ),
                Text(
                  'Classificação: '
                  '${sessao['classificacao'] ?? 'Sem análise'}',
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ==========================================================
  // TELA PREFERÊNCIAS
  // ==========================================================

  Widget telaPreferencias() {
    return Column(
      children: [
        cartao(
          'Acessibilidade',
          Column(
            children: [
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  title: const Text('Alto contraste'),
                  value: altoContraste,
                  onChanged: (valor) {
                    setState(() {
                      altoContraste = valor;
                    });
                  },
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: paleta,
                decoration: const InputDecoration(
                  labelText: 'Paleta de cores',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Padrão', child: Text('Padrão')),
                  DropdownMenuItem(
                    value: 'Protanopia',
                    child: Text('Protanopia'),
                  ),
                  DropdownMenuItem(
                    value: 'Deuteranopia',
                    child: Text('Deuteranopia'),
                  ),
                  DropdownMenuItem(
                    value: 'Tritanopia',
                    child: Text('Tritanopia'),
                  ),
                  DropdownMenuItem(
                    value: 'Acromatopsia',
                    child: Text('Acromatopsia'),
                  ),
                ],
                onChanged: (valor) {
                  if (valor != null) {
                    setState(() {
                      paleta = valor;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'As preferências visuais ainda são locais '
                'e serão sincronizadas com o perfil posteriormente.',
              ),
            ],
          ),
        ),
        cartao(
          'Minha conta',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'E-mail: '
                '${supabase.auth.currentUser?.email ?? 'Não informado'}',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await supabase.auth.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sair da conta'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // INTERFACE PRINCIPAL
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    const titulos = ['Painel', 'Jogos', 'Análise', 'Histórico', 'Preferências'];

    const icones = [
      Icons.dashboard_outlined,
      Icons.sports_esports_outlined,
      Icons.psychology_outlined,
      Icons.history,
      Icons.settings_outlined,
    ];

    Widget conteudo;

    if (carregando) {
      conteudo = const Center(
        child: Padding(
          padding: EdgeInsets.all(50),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (erro != null) {
      conteudo = cartao(
        'Erro ao consultar Supabase',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(erro!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: carregarDados,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    } else {
      switch (pagina) {
        case 0:
          conteudo = telaPainel();
          break;
        case 1:
          conteudo = telaJogos();
          break;
        case 2:
          conteudo = telaAnalise();
          break;
        case 3:
          conteudo = telaHistorico();
          break;
        default:
          conteudo = telaPreferencias();
      }
    }

    return Scaffold(
      backgroundColor: altoContraste ? Colors.black : const Color(0xFF04090D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF08151D),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ANHANGÁ',
              style: TextStyle(
                color: destaque,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const Text(
              'NOVERIS  •  SMART HOME 2050',
              style: TextStyle(fontSize: 10, letterSpacing: 1),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar dados',
            onPressed: carregarDados,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: () async {
              await supabase.auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: carregarDados,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              titulos[pagina],
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            conteudo,
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF071118),
        selectedIndex: pagina,
        indicatorColor: destaque.withValues(alpha: 0.22),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (indice) {
          setState(() {
            pagina = indice;
          });
        },
        destinations: [
          for (int i = 0; i < titulos.length; i++)
            NavigationDestination(icon: Icon(icones[i]), label: titulos[i]),
        ],
      ),
    );
  }
}
