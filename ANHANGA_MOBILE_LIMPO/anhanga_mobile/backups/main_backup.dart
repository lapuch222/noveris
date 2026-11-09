import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// CONFIGURAÃ‡ÃƒO SUPABASE
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
  if (valor == null) return 'â€”';
  final total = valor.round();
  final horas = total ~/ 60;
  final minutos = total % 60;
  return horas == 0 ? '${minutos}min' : '${horas}h ${minutos.toString().padLeft(2, '0')}min';
}

String formatarDataBR(Object? valor) {
  if (valor == null || valor.toString().isEmpty) return 'NÃ£o informado';
  final data = DateTime.tryParse(valor.toString())?.toLocal();
  if (data == null) return 'Data invÃ¡lida';
  String d(int n) => n.toString().padLeft(2, '0');
  return '${d(data.day)}/${d(data.month)}/${data.year} Ã s ${d(data.hour)}:${d(data.minute)}';
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
      title: 'ANHANGÃ',
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
// ABERTURA E AUTENTICAÃ‡ÃƒO
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

    timer = Timer(
      const Duration(seconds: 4),
      fecharAbertura,
    );
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
      return AnhangaAbertura(
        onEntrar: fecharAbertura,
      );
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
  const AnhangaAbertura({
    super.key,
    required this.onEntrar,
  });

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
                              0.5 *
                                  math.cos(
                                    2 * math.pi * animacao.value,
                                  );

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
                                top: lado *
                                    (0.1555 - 0.006 * pulso),
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
        throw const AuthException(
          'Preencha o e-mail e a senha.',
        );
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
        await supabase.auth.signInWithPassword(
          email: email,
          password: senha,
        );
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
        redirectTo:
            'com.noveris.anhanga_mobile://login-callback/',
      );
    } catch (erro) {
      if (mounted) {
        setState(() {
          mensagem = 'NÃ£o foi possÃ­vel entrar com Google: $erro';
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
              'Se o e-mail estiver cadastrado, vocÃª receberÃ¡ '
              'instruÃ§Ãµes de recuperaÃ§Ã£o.';
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
                  Image.asset(
                    'assets/images/anhanga_cervo.webp',
                    height: 150,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ANHANGÃ',
                    style: TextStyle(
                      color: azul,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    cadastro
                        ? 'Criar minha conta'
                        : 'Entrar na minha conta',
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
                      cadastro
                          ? 'JÃ¡ tenho conta'
                          : 'Criar uma conta',
                    ),
                  ),
                  TextButton(
                    onPressed: recuperarSenha,
                    child: const Text('Esqueci minha senha'),
                  ),
                  if (carregando)
                    const CircularProgressIndicator(),
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

  String paleta = 'PadrÃ£o';
  String? erro;

  List<Map<String, dynamic>> sessoes = [];
  List<Map<String, String>> jogosInstalados = [];
  bool carregandoJogos = false;
  String? erroJogos;
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

  Future<void> carregarJogos() async {
    if (!mounted) {
      return;
    }
    setState(() { carregandoJogos = true; erroJogos = null; });
    try {
      final resposta = await canalJogos.invokeMethod<List<dynamic>>('listarJogos');
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
        setState(() => erroJogos = 'IntegraÃ§Ã£o Android nÃ£o encontrada. Verifique o MainActivity.kt e reinicie o aplicativo.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => erroJogos = 'NÃ£o foi possÃ­vel consultar os jogos: $e');
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

  // Consulta somente registros que as polÃ­ticas RLS
  // do Supabase permitirem Ã  conta autenticada.
  //
  // IMPORTANTE: a associaÃ§Ã£o entre auth.users e
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
        throw Exception('UsuÃ¡rio nÃ£o autenticado.');
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

      final registros = List<Map<String, dynamic>>.from(
        resposta,
      );

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

        duracaoMedia = registros.isEmpty
            ? 0
            : minutos / registros.length;

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
        color: altoContraste
            ? Colors.black
            : const Color(0xFF0A1720),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: altoContraste
              ? Colors.white
              : const Color(0xFF1B3B4A),
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

  Widget telaPainel() {
    return Column(
      children: [
        cartao(
          'Bem-vindo ao ANHANGÃ',
          const Text(
            'AnÃ¡lise Neural de HÃ¡bitos, Ambiente '
            'e Gaming Adaptativo.\n\n'
            'Seu assistente inteligente para sessÃµes de jogos.',
          ),
        ),
        cartao(
          'Resumo das sessÃµes',
          Column(
            children: [
              Row(
                children: [
                  indicador(
                    'SessÃµes',
                    '$totalSessoes',
                  ),
                  const SizedBox(width: 10),
                  indicador(
                    'Tempo total',
                    formatarDuracao(totalMinutos),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  indicador(
                    'Pausas',
                    '$totalPausas',
                  ),
                  const SizedBox(width: 10),
                  indicador(
                    'MÃ©dia',
                    formatarDuracao(duracaoMedia),
                  ),
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
        cartao('EvoluÃ§Ã£o das sessÃµes', graficoSessoes()),
        cartao(
          'InteligÃªncia artificial',
          const Text(
            'Acesse a aba AnÃ¡lise para visualizar '
            'os resultados registrados das sessÃµes.\n\n'
            'A previsÃ£o de novas sessÃµes pela Edge Function '
            'serÃ¡ integrada posteriormente.',
          ),
        ),
      ],
    );
  }

  Widget graficoSessoes() {
    final ultimas = sessoes.take(7).toList().reversed.toList();
    if (ultimas.isEmpty) {
      return const Text('Ainda nÃ£o existem sessÃµes para o grÃ¡fico.');
    }
    final maior = ultimas.map((e) => inteiro(e['duracao_minutos'])).fold<int>(1, (a, b) => b > a ? b : a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DuraÃ§Ã£o das Ãºltimas sessÃµes (minutos)'),
        const SizedBox(height: 12),
        for (final sessao in ultimas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(width: 68, child: Text('#${sessao['id_fato']}')),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: inteiro(sessao['duracao_minutos']) / maior,
                      minHeight: 15,
                      color: destaque,
                      backgroundColor: const Color(0xFF203541),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 78, child: Text(formatarDuracao(inteiro(sessao['duracao_minutos'])))),
              ],
            ),
          ),
      ],
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
          const Text('Jogos identificados no Android. A lista pode ser limitada pelas regras de visibilidade do sistema.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: carregandoJogos ? null : carregarJogos,
            icon: const Icon(Icons.refresh),
            label: const Text('Buscar jogos'),
          ),
          if (carregandoJogos) const LinearProgressIndicator(),
          if (erroJogos != null) Text(erroJogos!, style: const TextStyle(color: Colors.orangeAccent)),
          if (!carregandoJogos && erroJogos == null && jogosInstalados.isEmpty)
            const Text('Nenhum jogo visÃ­vel foi identificado.'),
          for (final jogo in jogosInstalados)
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: const Icon(Icons.sports_esports_outlined),
                title: Text(jogo['nome'] ?? 'Jogo'),
                subtitle: Text(jogo['pacote'] ?? ''),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // TELA ANÃLISE
  // ==========================================================

  Widget telaAnalise() {
    if (sessoes.isEmpty) {
      return cartao(
        'AnÃ¡lise inteligente',
        const Text(
          'Nenhuma anÃ¡lise disponÃ­vel para esta conta '
          'ou nenhuma sessÃ£o acessÃ­vel.',
        ),
      );
    }

    final analisadas = sessoes.where((sessao) {
      return sessao['classificacao'] != null ||
          sessao['recomendacao'] != null;
    }).toList();

    return Column(
      children: [
        cartao(
          'AnÃ¡lise estatÃ­stica',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SessÃµes consultadas: $totalSessoes'),
              Text('Tempo total: ${formatarDuracao(totalMinutos)}'),
              Text('MÃ©dia: ${formatarDuracao(duracaoMedia)}'),
              Text('Total de pausas: $totalPausas'),
              const SizedBox(height: 12),
              const Text(
                'Estes resultados sÃ£o calculados '
                'a partir das sessÃµes retornadas pelo banco.',
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
                'SessÃµes com anÃ¡lise registrada: '
                '${analisadas.length}',
              ),
              const SizedBox(height: 12),
              if (analisadas.isEmpty)
                const Text('Nenhuma anÃ¡lise registrada.'),
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
                        'SessÃ£o #${sessao['id_fato']}',
                        style: TextStyle(
                          color: destaque,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ClassificaÃ§Ã£o: '
                        '${sessao['classificacao'] ?? 'NÃ£o informada'}',
                      ),
                      Text(
                        'Score de anomalia: '
                        '${sessao['score_anomalia'] ?? 'â€”'}',
                      ),
                      Text(
                        'Score de contexto: '
                        '${sessao['score_contexto'] ?? 'â€”'}',
                      ),
                      Text(
                        'DuraÃ§Ã£o prevista: '
                        '${sessao['duracao_prevista'] == null ? 'â€”' : formatarDuracao(decimal(sessao['duracao_prevista']))}',
                      ),
                      Text(
                        'Probabilidade registrada: '
                        '${sessao['probabilidade_prolongada'] ?? 'â€”'}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'RecomendaÃ§Ã£o: '
                        '${sessao['recomendacao'] ?? 'NÃ£o disponÃ­vel'}',
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
  // TELA HISTÃ“RICO
  // ==========================================================

  Widget telaHistorico() {
    if (sessoes.isEmpty) {
      return cartao(
        'HistÃ³rico de sessÃµes',
        const Text(
          'Nenhuma sessÃ£o disponÃ­vel.',
        ),
      );
    }

    return Column(
      children: [
        for (final sessao in sessoes)
          cartao(
            'SessÃ£o #${sessao['id_fato']}',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plataforma: '
                  '${sessao['plataforma'] ?? 'NÃ£o informada'}',
                ),
                Text(
                  'DuraÃ§Ã£o: '
                  '${formatarDuracao(inteiro(sessao['duracao_minutos']))}',
                ),
                Text(
                  'Pausas: '
                  '${sessao['quantidade_pausas'] ?? 0}',
                ),
                Text(
                  'InÃ­cio: '
                  '${formatarDataBR(sessao['inicio'])}',
                ),
                Text(
                  'ClassificaÃ§Ã£o: '
                  '${sessao['classificacao'] ?? 'Sem anÃ¡lise'}',
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ==========================================================
  // TELA PREFERÃŠNCIAS
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
                  DropdownMenuItem(
                    value: 'PadrÃ£o',
                    child: Text('PadrÃ£o'),
                  ),
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
                'As preferÃªncias visuais ainda sÃ£o locais '
                'e serÃ£o sincronizadas com o perfil posteriormente.',
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
                '${supabase.auth.currentUser?.email ?? 'NÃ£o informado'}',
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
    const titulos = [
      'Painel',
      'Jogos',
      'AnÃ¡lise',
      'HistÃ³rico',
      'PreferÃªncias',
    ];

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
      backgroundColor: altoContraste
          ? Colors.black
          : const Color(0xFF04090D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF08151D),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ANHANGÃ',
              style: TextStyle(
                color: destaque,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const Text(
              'NOVERIS  â€¢  SMART HOME 2050',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1,
              ),
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
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
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
        labelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (indice) {
          setState(() {
            pagina = indice;
          });
        },
        destinations: [
          for (int i = 0; i < titulos.length; i++)
            NavigationDestination(
              icon: Icon(icones[i]),
              label: titulos[i],
            ),
        ],
      ),
    );
  }
}
