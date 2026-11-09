import 'agenda_inteligente.dart';
import 'agenda_prazo_android.dart';
import 'agenda_automatica.dart';
import 'perfil_gamer_jogos.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'graficos_anhanga.dart';
import 'quarto_virtual.dart';

// ============================================================
// ANHANGÁ MOBILE — NOVERIS
// Versão com linguagem amigável para jogadores.
//
// Mantém:
// - Supabase e autenticação
// - Jogos instalados
// - Relógio flutuante Android
// - Histórico e nome dos jogos
// - Sincronização de partidas
// - Estatísticas reais
// - Resultados de IA registrados
// - Gráficos
// - Preferências de acessibilidade
//
// Não cria resultados fictícios.
// ============================================================

// ============================================================
// 1. CONFIGURAÇÕES
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

// ============================================================
// 2. FUNÇÕES AUXILIARES
// ============================================================

int numeroInteiro(Object? valor) {
  if (valor is num) return valor.toInt();

  return int.tryParse(valor?.toString() ?? '') ?? 0;
}

double numeroDecimal(Object? valor) {
  if (valor is num) return valor.toDouble();

  return double.tryParse(valor?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

String numeroBR(num valor, {int casas = 2}) {
  return valor.toStringAsFixed(casas).replaceAll('.', ',');
}

String duracaoTexto(num? minutos) {
  if (minutos == null) return 'Ainda sem informação';

  final total = minutos.round();
  final horas = total ~/ 60;
  final resto = total % 60;

  if (horas == 0) return '${resto}min';

  return '${horas}h ${resto.toString().padLeft(2, '0')}min';
}

// Compatibilidade com os testes existentes.
String formatarDuracao(num? minutos) {
  return duracaoTexto(minutos);
}

String formatarNumeroBR(num valor, {int casas = 1}) {
  return numeroBR(valor, casas: casas);
}

String dataTexto(Object? valor) {
  if (valor == null) return 'Ainda sem informação';

  final data = DateTime.tryParse(valor.toString())?.toLocal();

  if (data == null) return 'Data não disponível';

  String dois(int n) => n.toString().padLeft(2, '0');

  return '${dois(data.day)}/${dois(data.month)}/${data.year}'
      ' às ${dois(data.hour)}:${dois(data.minute)}';
}

String dataISO(DateTime data) {
  String dois(int n) => n.toString().padLeft(2, '0');

  return '${data.year}-${dois(data.month)}-${dois(data.day)}';
}

String nomeNormalizado(String nome) {
  return nome.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String dadoTexto(
  Map<String, dynamic> dados,
  String campo, {
  String unidade = '',
  int casas = 2,
}) {
  final valor = dados[campo];

  if (valor == null) return 'Ainda sem informação';

  if (valor is num) {
    return '${numeroBR(valor, casas: casas)}$unidade';
  }

  final numero = double.tryParse(valor.toString());

  if (numero != null) {
    return '${numeroBR(numero, casas: casas)}$unidade';
  }

  return '$valor$unidade';
}

// ============================================================
// 3. ESTATÍSTICAS DAS PARTIDAS
// ============================================================

class EstatisticasSessoes {
  const EstatisticasSessoes({
    required this.quantidade,
    required this.total,
    required this.media,
    required this.mediana,
    required this.desvio,
    required this.minimo,
    required this.maximo,
    required this.pausas,
    required this.comPausas,
  });

  final int quantidade;
  final double total;
  final double media;
  final double mediana;
  final double desvio;
  final double minimo;
  final double maximo;
  final int pausas;
  final int comPausas;

  int get semPausas => quantidade - comPausas;

  static EstatisticasSessoes calcular(List<Map<String, dynamic>> sessoes) {
    final validas = sessoes.where((s) {
      return s['duracao_minutos'] != null &&
          numeroDecimal(s['duracao_minutos']) >= 0;
    }).toList();

    if (validas.isEmpty) {
      return const EstatisticasSessoes(
        quantidade: 0,
        total: 0,
        media: 0,
        mediana: 0,
        desvio: 0,
        minimo: 0,
        maximo: 0,
        pausas: 0,
        comPausas: 0,
      );
    }

    final valores =
        validas.map((s) => numeroDecimal(s['duracao_minutos'])).toList()
          ..sort();

    final total = valores.fold<double>(0, (soma, valor) => soma + valor);

    final media = total / valores.length;
    final meio = valores.length ~/ 2;

    final mediana = valores.length.isOdd
        ? valores[meio]
        : (valores[meio - 1] + valores[meio]) / 2;

    final variancia =
        valores.fold<double>(
          0,
          (soma, valor) => soma + math.pow(valor - media, 2).toDouble(),
        ) /
        valores.length;

    final pausas = validas.fold<int>(
      0,
      (soma, s) => soma + numeroInteiro(s['quantidade_pausas']),
    );

    final comPausas = validas.where((s) {
      return numeroInteiro(s['quantidade_pausas']) > 0;
    }).length;

    return EstatisticasSessoes(
      quantidade: validas.length,
      total: total,
      media: media,
      mediana: mediana,
      desvio: math.sqrt(variancia),
      minimo: valores.first,
      maximo: valores.last,
      pausas: pausas,
      comPausas: comPausas,
    );
  }

  double? zScore(double duracao) {
    if (quantidade < 2 || desvio == 0) return null;
    return (duracao - media) / desvio;
  }

  String comparar(double duracao) {
    final z = zScore(duracao);

    if (z == null) {
      return 'Ainda não há partidas suficientes';
    }

    if (z >= 2) return 'Muito mais tempo que o normal';
    if (z >= 1) return 'Mais tempo que o normal';
    if (z <= -2) return 'Muito menos tempo que o normal';
    if (z <= -1) return 'Menos tempo que o normal';

    return 'Dentro do seu tempo habitual';
  }
}

// ============================================================
// 4. APLICATIVO
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
// 5. ABERTURA E LOGIN
// ============================================================

class AnhangaInicial extends StatefulWidget {
  const AnhangaInicial({super.key});

  @override
  State<AnhangaInicial> createState() => _AnhangaInicialState();
}

class _AnhangaInicialState extends State<AnhangaInicial> {
  bool abertura = true;

  Timer? timer;
  late final StreamSubscription<AuthState> assinaturaAuth;

  @override
  void initState() {
    super.initState();

    assinaturaAuth = supabase.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });

    timer = Timer(const Duration(seconds: 4), fecharAbertura);
  }

  void fecharAbertura() {
    if (!mounted) return;

    timer?.cancel();

    setState(() {
      abertura = false;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    assinaturaAuth.cancel();
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

    return AnhangaPainel(key: ValueKey(supabase.auth.currentUser?.id));
  }
}

// ============================================================
// 6. ANIMAÇÃO DE ABERTURA
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
// 7. ENTRAR OU CRIAR CONTA
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
        throw const AuthException('Preencha seu e-mail e sua senha.');
      }

      if (cadastro) {
        final resposta = await supabase.auth.signUp(
          email: email,
          password: senha,
        );

        if (resposta.session == null && mounted) {
          setState(() {
            mensagem = 'Conta criada! Confira seu e-mail para continuar.';
          });
        }
      } else {
        await supabase.auth.signInWithPassword(email: email, password: senha);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => mensagem = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => mensagem = 'Não foi possível entrar: $e');
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
    } catch (e) {
      if (mounted) {
        setState(() => mensagem = 'Não foi possível entrar: $e');
      }
    }
  }

  Future<void> recuperarSenha() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() => mensagem = 'Digite seu e-mail primeiro.');
      return;
    }

    try {
      await supabase.auth.resetPasswordForEmail(email);

      if (mounted) {
        setState(() {
          mensagem = 'Se a conta existir, você receberá instruções por e-mail.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => mensagem = 'Não foi possível enviar: $e');
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
                  const SizedBox(height: 8),
                  const Text(
                    'SEU COMPANHEIRO DE JOGO',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    cadastro ? 'Criar minha conta' : 'Bem-vindo de volta!',
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
                    child: Text(cadastro ? 'Criar minha conta' : 'Entrar'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: entrarGoogle,
                    icon: const Icon(Icons.account_circle),
                    label: const Text('Continuar com Google'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        cadastro = !cadastro;
                        mensagem = '';
                      });
                    },
                    child: Text(
                      cadastro ? 'Já tenho uma conta' : 'Quero criar uma conta',
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
// 8. TELA PRINCIPAL
// ============================================================

class AnhangaPainel extends StatefulWidget {
  const AnhangaPainel({super.key});

  @override
  State<AnhangaPainel> createState() => _AnhangaPainelState();
}

class _AnhangaPainelState extends State<AnhangaPainel>
    with WidgetsBindingObserver {
  static const canalJogos = MethodChannel('com.noveris.anhanga_mobile/jogos');

  static const canalRelogio = MethodChannel(
    'com.noveris.anhanga_mobile/relogio',
  );

  static const azul = Color(0xFF5FD4EC);

  int pagina = 0;
  int periodoDias = 0;

  bool carregando = true;
  bool carregandoJogos = false;
  bool altoContraste = false;

  bool sincronizandoSessoes = false;
  bool analisandoSessoesIA = false;
  bool atualizandoTudo = false;

  String paleta = 'Padrão';

  String? erro;
  String? erroJogos;
  String? erroSincronizacao;
  String? erroAnaliseIA;

  List<Map<String, dynamic>> sessoes = [];
  List<Map<String, String>> jogosInstalados = [];

  Map<int, String> nomesJogos = {};

  String? jogoSelecionado;
  String? jogoDaSessao;

  int limiteSessao = 60;

  bool sessaoIniciada = false;
  bool sessaoPausada = false;
  bool limiteAvisado = false;
  bool operacaoRelogio = false;

  int segundosNativos = 0;
  int limiteNativoSegundos = 0;

  Timer? timerSessao;

  final AgendaAutomatica agendaAutomatica = AgendaAutomatica();
  bool verificandoAgenda = false;
  DateTime? ultimaVerificacaoAgenda;

  final horasController = TextEditingController(text: '1');

  final minutosController = TextEditingController(text: '0');

  String? erroTempo;

  int sessoesEnviadas = 0;
  int sessoesSemProprietario = 0;

  int inteiro(Object? valor) => numeroInteiro(valor);
  double decimal(Object? valor) => numeroDecimal(valor);

  // ==========================================================
  // 9. TEXTOS PARA JOGADORES
  // ==========================================================

  String classificacaoJogador(Object? valor) {
    switch (valor?.toString().toLowerCase()) {
      case 'dentro_do_padrao':
        return 'Dentro do seu ritmo normal';

      case 'levemente_acima':
      case 'levemente_acima_do_padrao':
        return 'Um pouco mais longa que o normal';

      case 'acima':
      case 'acima_do_padrao':
        return 'Você jogou mais que o habitual';

      case 'muito_acima':
      case 'muito_acima_do_padrao':
        return 'Bem mais longa que o habitual';

      case 'levemente_abaixo':
      case 'levemente_abaixo_do_padrao':
        return 'Um pouco mais curta que o normal';

      case 'abaixo':
      case 'abaixo_do_padrao':
        return 'Você jogou menos que o habitual';

      case 'muito_abaixo':
      case 'muito_abaixo_do_padrao':
        return 'Bem mais curta que o habitual';

      case 'risco_elevado':
        return 'Atenção ao seu tempo de jogo';

      case 'risco_abaixo_do_limiar':
        return 'Baixo risco de ultrapassar o tempo';

      default:
        return 'Ainda não avaliada';
    }
  }

  String dicaJogador(Object? recomendacao) {
    final texto = recomendacao?.toString().trim();

    if (texto == null || texto.isEmpty) {
      return 'Ainda não temos uma dica para esta partida.';
    }

    final normalizado = texto.toLowerCase();

    if (normalizado.contains('ultrapassou o limite')) {
      return 'Você passou do tempo que tinha escolhido '
          'para jogar. Que tal descansar um pouco?';
    }

    if (normalizado.contains('considere fazer uma pausa')) {
      return 'Que tal fazer uma pausa para descansar?';
    }

    if (normalizado.contains('abaixo do seu padrao')) {
      return 'Hoje você jogou menos que de costume.';
    }

    if (normalizado.contains('proxima do padrao')) {
      return 'Seu tempo de jogo ficou próximo do habitual.';
    }

    if (normalizado.contains('continue acompanhando')) {
      return 'Continue de olho no seu tempo de jogo '
          'e nas suas pausas.';
    }

    return texto;
  }

  String nomePlataforma(Object? valor) {
    final texto = valor?.toString().toLowerCase() ?? '';

    if (texto == 'pc') return 'Computador';
    if (texto == 'android') return 'Celular';

    return valor?.toString() ?? 'Não informado';
  }

  // ==========================================================
  // 10. CICLO DE VIDA
  // ==========================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    carregarJogos();

    timerSessao = Timer.periodic(
      const Duration(seconds: 1),
      atualizarCronometro,
    );

    sincronizarRelogio();
    atualizarTudo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      sincronizarRelogio();
      atualizarTudo();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    timerSessao?.cancel();
    horasController.dispose();
    minutosController.dispose();

    super.dispose();
  }

  void mostrarMensagem(String texto) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), duration: const Duration(seconds: 5)),
    );
  }

  // ==========================================================
  // 11. CATÁLOGO E NOMES DOS JOGOS
  // ==========================================================

  void abrirQuartoVirtual() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuartoVirtualPage(sessoes: sessoes),
      ),
    );
  }

  Future<void> carregarCatalogoJogos() async {
    final authId = supabase.auth.currentUser?.id;
    if (authId == null) return;

    try {
      final resposta = await supabase
          .from('dim_jogo')
          .select('id_jogo, nome_jogo');

      if (!mounted || supabase.auth.currentUser?.id != authId) {
        return;
      }

      final catalogo = <int, String>{};

      for (final item in resposta) {
        final id = inteiro(item['id_jogo']);
        final nome = item['nome_jogo']?.toString() ?? '';

        if (id > 0 && nome.isNotEmpty) {
          catalogo[id] = nome;
        }
      }

      setState(() {
        nomesJogos = catalogo;
      });
    } catch (e) {
      debugPrint('Erro ao carregar jogos cadastrados: $e');
    }
  }

  String nomeJogoHistorico(Map<String, dynamic> sessao) {
    final idJogo = inteiro(sessao['id_jogo']);

    final cadastrado = nomesJogos[idJogo];

    if (cadastrado != null && cadastrado.isNotEmpty) {
      return cadastrado;
    }

    final original = sessao['nome_jogo_original']?.toString().trim();

    if (original != null && original.isNotEmpty) {
      return original;
    }

    return 'Jogo não informado';
  }

  // ==========================================================
  // 12. SINCRONIZAR PARTIDAS DO CELULAR
  // ==========================================================

  Future<void> sincronizarSessoesPendentes({
    bool mostrarResultado = false,
  }) async {
    if (sincronizandoSessoes) return;

    final usuarioAuth = supabase.auth.currentUser;
    if (usuarioAuth == null) return;

    sincronizandoSessoes = true;

    if (mounted) {
      setState(() => erroSincronizacao = null);
    }

    int enviadas = 0;
    int semProprietario = 0;

    try {
      final resposta = await canalRelogio.invokeMethod<List<dynamic>>(
        'obterSessoesPendentes',
      );

      final pendentes = resposta ?? [];

      if (pendentes.isEmpty) {
        if (mostrarResultado) {
          mostrarMensagem('Todas as suas partidas estão em dia!');
        }
        return;
      }

      final usuario = await supabase
          .from('dim_usuario')
          .select('id_usuario')
          .eq('auth_user_id', usuarioAuth.id)
          .maybeSingle();

      if (usuario == null) {
        throw Exception('Não foi possível encontrar seu perfil de jogador.');
      }

      final idUsuario = usuario['id_usuario'];

      final dispositivos = await supabase
          .from('dim_dispositivo')
          .select('id_dispositivo, tipo_dispositivo, modelo');

      final androids = dispositivos.where((item) {
        final tipo = (item['tipo_dispositivo'] ?? '').toString().toLowerCase();

        final modelo = (item['modelo'] ?? '').toString().toLowerCase();

        return tipo.contains('smartphone') && modelo.contains('android');
      }).toList();

      if (androids.length != 1) {
        throw Exception('Não foi possível identificar seu celular.');
      }

      final idDispositivo = androids.single['id_dispositivo'];

      final jogos = await supabase
          .from('dim_jogo')
          .select('id_jogo, nome_jogo');

      for (final item in pendentes) {
        if (supabase.auth.currentUser?.id != usuarioAuth.id) {
          break;
        }

        final sessao = Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(item as Map),
        );

        final uuid = sessao['sessao_uuid']?.toString();

        if (uuid == null || uuid.isEmpty) {
          continue;
        }

        if (sessao['auth_user_id'] != usuarioAuth.id) {
          semProprietario++;
          continue;
        }

        final existente = await supabase
            .from('fato_ia')
            .select('id_fato, id_usuario')
            .eq('sessao_uuid', uuid)
            .maybeSingle();

        if (existente != null) {
          if (existente['id_usuario'] == idUsuario &&
              supabase.auth.currentUser?.id == usuarioAuth.id) {
            await canalRelogio.invokeMethod<bool>('confirmarSessaoSalva', {
              'sessaoUuid': uuid,
            });
          }
          continue;
        }

        final inicioMs = (sessao['inicio'] as num).toInt();
        final fimMs = (sessao['fim'] as num).toInt();

        if (fimMs < inicioMs) {
          throw Exception('Horário inválido na partida $uuid.');
        }

        final inicio = DateTime.fromMillisecondsSinceEpoch(
          inicioMs,
          isUtc: true,
        );

        final fim = DateTime.fromMillisecondsSinceEpoch(fimMs, isUtc: true);

        final data = dataISO(inicio.toLocal());

        final tempo = await supabase
            .from('dim_tempo')
            .select('id_tempo')
            .eq('data', data)
            .maybeSingle();

        if (tempo == null) {
          throw Exception('Não foi possível salvar a data desta partida.');
        }

        final nomeOriginal = sessao['jogo']?.toString().trim() ?? '';

        final nomeBusca = nomeNormalizado(nomeOriginal);

        int? idJogo;

        for (final jogo in jogos) {
          if (nomeNormalizado(jogo['nome_jogo']?.toString() ?? '') ==
              nomeBusca) {
            idJogo = inteiro(jogo['id_jogo']);
            break;
          }
        }

        final duracaoSegundos = (sessao['duracao_segundos'] as num).toDouble();

        final limiteSegundos = (sessao['limite_segundos'] as num?)?.toDouble();

        final pausas = (sessao['quantidade_pausas'] as num?)?.toInt() ?? 0;

        if (duracaoSegundos < 0 || pausas < 0) {
          throw Exception('Dados inválidos na partida $uuid.');
        }

        final registro = <String, dynamic>{
          'id_usuario': idUsuario,
          'id_dispositivo': idDispositivo,
          'id_tempo': tempo['id_tempo'],
          'id_jogo': idJogo,
          'nome_jogo_original': nomeOriginal.isEmpty ? null : nomeOriginal,
          'plataforma': 'Android',
          'inicio': inicio.toIso8601String(),
          'fim': fim.toIso8601String(),
          'duracao_minutos': duracaoSegundos / 60,
          'quantidade_pausas': pausas,
          'limite_minutos_sessao': limiteSegundos != null && limiteSegundos > 0
              ? limiteSegundos / 60
              : null,
          'sessao_uuid': uuid,
          'origem_dados': 'ANHANGA_MOBILE',
        };

        try {
          await supabase.from('fato_ia').insert(registro);
        } on PostgrestException catch (e) {
          if (e.code != '23505') rethrow;
        }

        final confirmacao = await supabase
            .from('fato_ia')
            .select('id_fato, id_usuario')
            .eq('sessao_uuid', uuid)
            .maybeSingle();

        if (confirmacao != null &&
            confirmacao['id_usuario'] == idUsuario &&
            supabase.auth.currentUser?.id == usuarioAuth.id) {
          final removida = await canalRelogio.invokeMethod<bool>(
            'confirmarSessaoSalva',
            {'sessaoUuid': uuid},
          );

          if (removida == true) {
            enviadas++;
          }
        }
      }

      if (mostrarResultado && mounted) {
        mostrarMensagem('$enviadas partidas sincronizadas.');
      }
    } on MissingPluginException {
      erroSincronizacao = 'O acompanhamento de partidas não está disponível.';
    } catch (e) {
      erroSincronizacao = e.toString();

      if (mostrarResultado && mounted) {
        mostrarMensagem('Não foi possível atualizar suas partidas: $e');
      }
    } finally {
      sincronizandoSessoes = false;

      if (mounted) {
        setState(() {
          sessoesEnviadas = enviadas;
          sessoesSemProprietario = semProprietario;
        });
      }
    }
  }

  // ==========================================================
  // 13. AVALIAR NOVAS PARTIDAS
  // ==========================================================

  Future<bool> analisarSessaoIA(int idFato) async {
    final sessaoAuth = supabase.auth.currentSession;

    if (sessaoAuth == null) return false;

    final authId = sessaoAuth.user.id;

    try {
      final resposta = await supabase.functions.invoke(
        'analisar-sessao',
        body: {'id_fato': idFato},
        headers: {'Authorization': 'Bearer ${sessaoAuth.accessToken}'},
      );

      if (supabase.auth.currentUser?.id != authId) {
        return false;
      }

      final dados = Map<String, dynamic>.from(resposta.data as Map);

      if (dados['erro'] != null) {
        throw Exception(dados['erro']);
      }

      return dados['status'] == 'analisada' ||
          dados['status'] == 'ja_analisada';
    } catch (e) {
      debugPrint('Erro na avaliação da partida $idFato: $e');

      if (mounted) {
        setState(() {
          erroAnaliseIA = e.toString();
        });
      }

      return false;
    }
  }

  Future<void> analisarSessoesPendentesIA() async {
    if (analisandoSessoesIA) return;

    final authId = supabase.auth.currentUser?.id;
    if (authId == null) return;

    analisandoSessoesIA = true;

    try {
      final pendentes = await supabase
          .from('fato_ia')
          .select('id_fato, classificacao, limite_minutos_sessao')
          .eq('plataforma', 'Android')
          .isFilter('classificacao', null)
          .not('limite_minutos_sessao', 'is', null)
          .order('id_fato', ascending: false)
          .limit(20);

      for (final sessao in pendentes) {
        if (supabase.auth.currentUser?.id != authId) {
          break;
        }

        final id = inteiro(sessao['id_fato']);

        if (id > 0) {
          await analisarSessaoIA(id);
        }
      }
    } catch (e) {
      debugPrint('Erro ao avaliar partidas: $e');
    } finally {
      analisandoSessoesIA = false;
    }
  }

  // ==========================================================
  // 14. ATUALIZAR TUDO
  // ==========================================================

  Future<void> atualizarTudo() async {
    if (atualizandoTudo) return;

    atualizandoTudo = true;

    try {
      await sincronizarSessoesPendentes();
      await analisarSessoesPendentesIA();
      await carregarCatalogoJogos();
      await carregarDados();
    } finally {
      atualizandoTudo = false;
    }
  }

  // ==========================================================
  // 15. CARREGAR PARTIDAS E AVALIAÇÕES
  // ==========================================================

  Future<void> carregarDados() async {
    if (!mounted) return;

    final authId = supabase.auth.currentUser?.id;

    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      if (authId == null) {
        throw Exception('Entre na sua conta.');
      }

      final resposta = await supabase
          .from('fato_ia')
          .select(
            'id_fato, id_usuario, id_jogo, '
            'nome_jogo_original, sessao_uuid, '
            'plataforma, inicio, fim, '
            'duracao_minutos, quantidade_pausas, '
            'sessoes_no_dia, '
            'temperatura, umidade, luminosidade, '
            'ruido_db, classificacao, score_anomalia, '
            'score_contexto, duracao_prevista, '
            'probabilidade_prolongada, confianca, '
            'recomendacao, explicacao, data_analise, '
            'limite_minutos_sessao, origem_dados',
          )
          .order('id_fato', ascending: false)
          .limit(1000);

      if (!mounted || supabase.auth.currentUser?.id != authId) {
        return;
      }

      final registros = List<Map<String, dynamic>>.from(resposta);

      setState(() {
        sessoes = registros;
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        erro = e.toString();
        carregando = false;
        sessoes = [];
      });
    }
  }

  // ==========================================================
  // 16. RELÓGIO FLUTUANTE
  // ==========================================================

  Duration get tempoDecorrido => Duration(seconds: segundosNativos);

  String relogioTexto(Duration duracao) {
    final segundos = duracao.inSeconds.clamp(0, 8639999);

    String dois(int n) => n.toString().padLeft(2, '0');

    final h = segundos ~/ 3600;
    final m = (segundos % 3600) ~/ 60;
    final s = segundos % 60;

    return '${dois(h)}:${dois(m)}:${dois(s)}';
  }

  Future<void> sincronizarRelogio() async {
    if (operacaoRelogio) return;

    try {
      final estado = await canalRelogio.invokeMapMethod<String, dynamic>(
        'obterEstado',
      );

      if (!mounted || estado == null) return;

      final ativo = estado['ativo'] == true;
      final pausado = estado['pausado'] == true;

      final decorrido = (estado['decorridoSegundos'] as num?)?.toInt() ?? 0;

      final limite = (estado['limiteSegundos'] as num?)?.toInt() ?? 0;

      final jogo = estado['jogo']?.toString();

      final atingiu = ativo && limite > 0 && decorrido >= limite;

      final avisar = atingiu && !limiteAvisado;

      setState(() {
        sessaoIniciada = ativo;
        sessaoPausada = pausado;
        segundosNativos = ativo ? decorrido : 0;
        limiteNativoSegundos = ativo ? limite : 0;

        if (ativo && limite > 0) {
          limiteSessao = (limite / 60).ceil();
        }

        if (ativo && jogo != null) {
          jogoDaSessao = jogo;
        }

        if (!ativo) {
          jogoDaSessao = null;
          limiteAvisado = false;
        } else if (atingiu) {
          limiteAvisado = true;
        }
      });

      if (avisar) {
        mostrarMensagem(
          'Você chegou ao tempo combinado. '
          'Que tal descansar um pouco?',
        );
      }
    } on MissingPluginException {
      debugPrint('Relógio Android não disponível.');
    } on PlatformException catch (e) {
      debugPrint('Erro no relógio: ${e.message}');
    }
  }

  void atualizarCronometro(Timer _) {
    if (!mounted) return;
    sincronizarRelogio();

    if (sessaoIniciada && !sessaoPausada) {
      unawaited(verificarAgendaAutomatica());
    }
  }

  Future<void> verificarAgendaAutomatica({
    bool solicitarPermissao = false,
  }) async {
    if (!mounted || !sessaoIniciada || verificandoAgenda) {
      return;
    }

    final agora = DateTime.now();

    if (!solicitarPermissao &&
        ultimaVerificacaoAgenda != null &&
        agora.difference(ultimaVerificacaoAgenda!) <
            const Duration(minutes: 1)) {
      return;
    }

    verificandoAgenda = true;
    ultimaVerificacaoAgenda = agora;

    try {
      final aviso = await agendaAutomatica.verificar(
        segundosJogados: segundosNativos,
        limiteSegundos: limiteNativoSegundos,
        solicitarPermissao: solicitarPermissao,
      );

      if (!mounted || !sessaoIniciada) return;

      if (aviso != null) {
        mostrarMensagem(aviso);
      }
    } finally {
      verificandoAgenda = false;
    }
  }

  Future<void> iniciarSessao() async {
    if (jogoSelecionado == null || sessaoIniciada || operacaoRelogio) {
      return;
    }

    final usuarioAuth = supabase.auth.currentUser;

    if (usuarioAuth == null) {
      mostrarMensagem('Entre na sua conta primeiro.');
      return;
    }

    operacaoRelogio = true;

    try {
      final permitido =
          await canalRelogio.invokeMethod<bool>('temPermissaoSobreposicao') ??
          false;

      if (!permitido) {
        await canalRelogio.invokeMethod<void>('solicitarPermissaoSobreposicao');

        mostrarMensagem('Permita que o relógio apareça sobre seus jogos.');

        return;
      }

      String nome = jogoSelecionado!;

      for (final jogo in jogosInstalados) {
        if (jogo['pacote'] == jogoSelecionado) {
          nome = jogo['nome'] ?? nome;
          break;
        }
      }

      final agendaPrazo = await AgendaPrazoAndroid.buscar(
        limiteSegundos: limiteSessao * 60,
      );

      if (!mounted) return;

      await canalRelogio.invokeMethod<void>('iniciarSessao', {
        'limiteSegundos': limiteSessao * 60,
        'jogo': nome,
        'authUserId': usuarioAuth.id,
        'agendaPrazoMs': agendaPrazo,
      });

      if (!mounted) return;

      setState(() {
        sessaoIniciada = true;
        sessaoPausada = false;
        limiteAvisado = false;
        segundosNativos = 0;
        limiteNativoSegundos = limiteSessao * 60;
        jogoDaSessao = nome;
      });

      mostrarMensagem('Boa partida! Seu tempo já está contando.');
      unawaited(verificarAgendaAutomatica(solicitarPermissao: true));
    } on PlatformException catch (e) {
      mostrarMensagem('Não foi possível começar: ${e.message ?? e.code}');
    } on MissingPluginException {
      mostrarMensagem('O relógio não está disponível neste aparelho.');
    } finally {
      operacaoRelogio = false;
      await sincronizarRelogio();
    }
  }

  Future<void> pausarOuContinuarSessao() async {
    if (!sessaoIniciada || operacaoRelogio) return;

    operacaoRelogio = true;

    final estavaPausada = sessaoPausada;

    try {
      await canalRelogio.invokeMethod<void>(
        estavaPausada ? 'continuarSessao' : 'pausarSessao',
      );

      mostrarMensagem(
        estavaPausada
            ? 'Vamos continuar sua partida!'
            : 'Pausa registrada! Aproveite para descansar.',
      );
    } on PlatformException catch (e) {
      mostrarMensagem('Não foi possível atualizar o relógio: ${e.message}');
    } finally {
      operacaoRelogio = false;
      await sincronizarRelogio();
    }
  }

  Future<void> encerrarSessao() async {
    if (operacaoRelogio) return;

    operacaoRelogio = true;
    bool encerrou = false;

    try {
      await canalRelogio.invokeMethod<void>('encerrarSessao');

      encerrou = true;

      if (mounted) {
        setState(() {
          sessaoIniciada = false;
          sessaoPausada = false;
          segundosNativos = 0;
          limiteNativoSegundos = 0;
          jogoDaSessao = null;
          limiteAvisado = false;
        });
      }

      mostrarMensagem('Partida finalizada! Vamos atualizar seu histórico.');
    } on PlatformException catch (e) {
      mostrarMensagem('Não foi possível encerrar: ${e.message}');
    } finally {
      operacaoRelogio = false;
      await sincronizarRelogio();
    }

    if (encerrou) {
      await Future<void>.delayed(const Duration(milliseconds: 350));

      await atualizarTudo();
    }
  }

  void definirTempoManual() {
    if (sessaoIniciada) {
      setState(() {
        erroTempo = 'Encerre sua partida antes de mudar o tempo.';
      });
      return;
    }

    final horas = int.tryParse(horasController.text.trim());

    final minutos = int.tryParse(minutosController.text.trim());

    if (horas == null ||
        minutos == null ||
        horas < 0 ||
        horas > 23 ||
        minutos < 0 ||
        minutos > 59 ||
        (horas == 0 && minutos == 0)) {
      setState(() {
        erroTempo = 'Escolha um tempo entre 1 minuto e 23h59.';
      });
      return;
    }

    setState(() {
      limiteSessao = horas * 60 + minutos;
      erroTempo = null;
    });

    FocusScope.of(context).unfocus();

    mostrarMensagem('Pronto! Seu tempo de jogo foi definido.');
  }

  // ==========================================================
  // 17. BUSCAR JOGOS INSTALADOS
  // ==========================================================

  Future<void> carregarJogos() async {
    if (!mounted) return;

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
        setState(() {
          jogosInstalados = jogos;
        });
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          erroJogos = 'Não foi possível acessar seus jogos.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          erroJogos = 'Não foi possível buscar seus jogos: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => carregandoJogos = false);
      }
    }
  }

  // ==========================================================
  // 18. CORES E VISUAL
  // ==========================================================

  Color get destaque {
    if (altoContraste) return Colors.yellow;

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

  Widget linha(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(titulo)),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: TextStyle(color: destaque, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget subtitulo(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Text(
        titulo,
        style: TextStyle(
          color: destaque,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ==========================================================
  // 19. GRÁFICOS
  // ==========================================================

  List<Map<String, dynamic>> get sessoesPeriodo {
    if (periodoDias == 0) return sessoes;

    final inicio = DateTime.now().subtract(Duration(days: periodoDias));

    return sessoes.where((sessao) {
      final data = DateTime.tryParse(sessao['inicio']?.toString() ?? '');

      return data != null && !data.toLocal().isBefore(inicio);
    }).toList();
  }

  String get descricaoPeriodo =>
      periodoDias == 0 ? 'Todas as partidas' : 'Últimos $periodoDias dias';

  double get minutosPeriodo => sessoesPeriodo.fold<double>(
    0,
    (soma, s) => soma + decimal(s['duracao_minutos']),
  );

  int get pausasPeriodo => sessoesPeriodo.fold<int>(
    0,
    (soma, s) => soma + inteiro(s['quantidade_pausas']),
  );

  double get mediaPeriodo =>
      sessoesPeriodo.isEmpty ? 0 : minutosPeriodo / sessoesPeriodo.length;

  List<PontoSessao> get pontosRecentes =>
      sessoesPeriodo.take(7).map(PontoSessao.deMapa).toList().reversed.toList();

  PaletaGraficos get paletaDosGraficos => PaletaGraficos.de(
    paleta: paleta,
    altoContraste: altoContraste,
    destaque: destaque,
  );

  Widget graficoSessoes() {
    return GraficoHorizontalSessoes(
      pontos: pontosRecentes,
      paleta: paletaDosGraficos,
      periodo: descricaoPeriodo,
      limite: limiteSessao.toDouble(),
    );
  }

  Widget graficoBarras() {
    return GraficoCartesianoSessoes(
      pontos: pontosRecentes,
      paleta: paletaDosGraficos,
      periodo: descricaoPeriodo,
      linhas: false,
      limite: limiteSessao.toDouble(),
    );
  }

  List<PontoSessao> get pontosPorDia {
    final totais = <DateTime, double>{};

    for (final sessao in sessoesPeriodo) {
      final data = DateTime.tryParse(sessao['inicio']?.toString() ?? '')
          ?.toLocal();

      if (data == null) continue;

      final dia = DateTime(data.year, data.month, data.day);

      totais[dia] = (totais[dia] ?? 0) + decimal(sessao['duracao_minutos']);
    }

    final dias = totais.keys.toList()..sort();

    return dias.reversed
        .take(7)
        .toList()
        .reversed
        .map((dia) => PontoSessao(id: 0, minutos: totais[dia]!, inicio: dia))
        .toList();
  }

  Widget graficoLinhas() {
    return GraficoCartesianoSessoes(
      pontos: pontosPorDia,
      paleta: paletaDosGraficos,
      periodo: descricaoPeriodo,
      linhas: true,
      limite: null,
    );
  }

  Widget graficoRosca() {
    final dados = sessoesPeriodo;

    final comPausas = dados.where((s) {
      return inteiro(s['quantidade_pausas']) > 0;
    }).length;

    return GraficoRoscaPausas(
      comPausas: comPausas,
      semPausas: dados.length - comPausas,
      paleta: paletaDosGraficos,
      periodo: descricaoPeriodo,
    );
  }

  Widget filtrosDashboard() {
    return cartao(
      'Escolha o período',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            initialValue: periodoDias,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Mostrar partidas de',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Todo o histórico')),
              DropdownMenuItem(value: 7, child: Text('Últimos 7 dias')),
              DropdownMenuItem(value: 30, child: Text('Últimos 30 dias')),
              DropdownMenuItem(value: 90, child: Text('Últimos 90 dias')),
            ],
            onChanged: (valor) {
              if (valor != null) {
                setState(() => periodoDias = valor);
              }
            },
          ),
          const SizedBox(height: 12),
          Text('Partidas encontradas: ${sessoesPeriodo.length}'),
          Text('Tempo jogado: ${duracaoTexto(minutosPeriodo)}'),
        ],
      ),
    );
  }

  // ==========================================================
  // 20. INÍCIO
  // ==========================================================

  Widget telaPainel() {
    return Column(
      children: [
        cartao(
          'Olá, jogador!',
          const Text(
            'Tudo pronto para mais uma partida?\n\n'
            'Acompanhe seu tempo de jogo, suas pausas '
            'e descubra como anda seu ritmo.',
          ),
        ),

        cartao(
          'Meu Quarto',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Controle a luz, a temperatura '
                'e o barulho do seu quarto gamer virtual.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: abrirQuartoVirtual,
                icon: const Icon(Icons.meeting_room_outlined),
                label: const Text('Entrar no meu quarto'),
              ),
            ],
          ),
        ),
        filtrosDashboard(),

        cartao(
          'Seu tempo de jogo',
          Column(
            children: [
              Row(
                children: [
                  indicador('Partidas', '${sessoesPeriodo.length}'),
                  const SizedBox(width: 10),
                  indicador('Tempo jogado', duracaoTexto(minutosPeriodo)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  indicador('Pausas', '$pausasPeriodo'),
                  const SizedBox(width: 10),
                  indicador('Tempo médio', duracaoTexto(mediaPeriodo)),
                ],
              ),
            ],
          ),
        ),

        cartao(
          'Suas partidas estão em dia?',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Atualize suas partidas para acompanhar '
                'seu tempo de jogo.',
              ),
              if (sincronizandoSessoes || analisandoSessoesIA)
                const LinearProgressIndicator(),
              if (erroSincronizacao != null)
                Text(
                  erroSincronizacao!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: atualizandoTudo ? null : atualizarTudo,
                icon: const Icon(Icons.sync),
                label: const Text('Atualizar minhas partidas'),
              ),
            ],
          ),
        ),

        cartao('Suas últimas partidas', graficoSessoes()),

        cartao('Tempo de cada partida', graficoBarras()),

        cartao('Como anda seu tempo de jogo?', graficoLinhas()),

        cartao('Você costuma fazer pausas?', graficoRosca()),

        cartao(
          'Conheça seu ritmo',
          const Text(
            'Na aba Meu ritmo, você pode descobrir '
            'quanto costuma jogar, como foram suas partidas '
            'e quais dicas estão disponíveis para você.',
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // 21. MEUS JOGOS
  // ==========================================================

  Widget telaJogos() {
    final limiteAtivo = sessaoIniciada
        ? limiteNativoSegundos
        : limiteSessao * 60;

    final restante = math.max(0, limiteAtivo - segundosNativos);

    final progresso = limiteAtivo > 0
        ? (segundosNativos / limiteAtivo).clamp(0.0, 1.0)
        : 0.0;

    String nomeSelecionado = jogoSelecionado ?? '';

    for (final jogo in jogosInstalados) {
      if (jogo['pacote'] == jogoSelecionado) {
        nomeSelecionado = jogo['nome'] ?? nomeSelecionado;
        break;
      }
    }

    return cartao(
      'Seus jogos',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Escolha um jogo e quanto tempo quer jogar.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: carregandoJogos ? null : carregarJogos,
            icon: const Icon(Icons.refresh),
            label: const Text('Procurar meus jogos'),
          ),
          if (carregandoJogos) const LinearProgressIndicator(),
          if (erroJogos != null)
            Text(
              erroJogos!,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          if (!carregandoJogos && erroJogos == null && jogosInstalados.isEmpty)
            const Text('Nenhum jogo encontrado.'),

          if (jogoSelecionado != null) ...[
            const SizedBox(height: 12),
            Text('Seu jogo: $nomeSelecionado'),
            const SizedBox(height: 12),
            Text(
              'Tempo escolhido: ${duracaoTexto(limiteSessao)}',
              style: TextStyle(
                color: destaque,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: horasController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Horas',
                      border: OutlineInputBorder(),
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
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (erroTempo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  erroTempo!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: definirTempoManual,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirmar meu tempo'),
            ),
          ],

          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF102431),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sessaoIniciada
                      ? (sessaoPausada
                            ? 'Sua partida está pausada'
                            : 'Você está jogando!')
                      : 'Pronto para começar?',
                  style: TextStyle(
                    color: destaque,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (jogoDaSessao != null) Text('Jogo: $jogoDaSessao'),
                const SizedBox(height: 12),
                Text(
                  'Tempo jogado: '
                  '${relogioTexto(tempoDecorrido)}',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Tempo restante: '
                  '${relogioTexto(Duration(seconds: restante))}',
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progresso,
                  minHeight: 8,
                  color: destaque,
                  backgroundColor: const Color(0xFF294454),
                ),
                if (sessaoIniciada &&
                    limiteAtivo > 0 &&
                    segundosNativos >= limiteAtivo)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Você chegou ao tempo combinado!',
                      style: TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                const SizedBox(height: 16),
                if (!sessaoIniciada)
                  FilledButton.icon(
                    onPressed: jogoSelecionado == null ? null : iniciarSessao,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Começar a jogar'),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: pausarOuContinuarSessao,
                        icon: Icon(
                          sessaoPausada ? Icons.play_arrow : Icons.pause,
                        ),
                        label: Text(
                          sessaoPausada ? 'Continuar' : 'Fazer uma pausa',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: encerrarSessao,
                        icon: const Icon(Icons.stop),
                        label: const Text('Finalizar partida'),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          for (final jogo in jogosInstalados)
            ListTile(
              leading: Icon(
                jogoSelecionado == jogo['pacote']
                    ? Icons.check_circle
                    : Icons.sports_esports_outlined,
                color: destaque,
              ),
              selected: jogoSelecionado == jogo['pacote'],
              onTap: () {
                setState(() {
                  jogoSelecionado = jogo['pacote'];
                });
              },
              title: Text(jogo['nome'] ?? 'Jogo'),
              subtitle: Text(jogo['pacote'] ?? ''),
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // 22. COMO FORAM SUAS PARTIDAS?
  // ==========================================================

  bool possuiAnaliseDetalhada(Map<String, dynamic> sessao) {
    return sessao['score_anomalia'] != null ||
        sessao['score_contexto'] != null ||
        sessao['duracao_prevista'] != null ||
        sessao['probabilidade_prolongada'] != null ||
        sessao['recomendacao'] != null;
  }

  Widget resultadoSalvoSupabase(Map<String, dynamic> sessao) {
    final temAmbiente =
        sessao['temperatura'] != null ||
        sessao['umidade'] != null ||
        sessao['luminosidade'] != null ||
        sessao['ruido_db'] != null;

    return cartao(
      'Partida ${sessao['id_fato']}',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_esports, color: destaque, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nomeJogoHistorico(sessao),
                  style: TextStyle(
                    color: destaque,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          linha('Onde você jogou', nomePlataforma(sessao['plataforma'])),

          linha(
            'Tempo jogado',
            dadoTexto(sessao, 'duracao_minutos', unidade: ' min'),
          ),

          linha(
            'Pausas feitas',
            dadoTexto(sessao, 'quantidade_pausas', casas: 0),
          ),

          if (sessao['sessoes_no_dia'] != null)
            linha(
              'Partidas naquele dia',
              dadoTexto(sessao, 'sessoes_no_dia', casas: 0),
            ),

          const Divider(),

          subtitulo('Como foi sua partida'),

          linha('Seu ritmo', classificacaoJogador(sessao['classificacao'])),

          if (sessao['score_anomalia'] != null)
            linha(
              'Mudança no seu jeito de jogar',
              dadoTexto(sessao, 'score_anomalia'),
            ),

          if (sessao['score_contexto'] != null)
            linha(
              'Condições ao seu redor',
              dadoTexto(sessao, 'score_contexto'),
            ),

          if (sessao['duracao_prevista'] != null)
            linha(
              'Tempo estimado',
              dadoTexto(sessao, 'duracao_prevista', unidade: ' min'),
            ),

          if (sessao['probabilidade_prolongada'] != null)
            linha(
              'Risco de passar do tempo',
              dadoTexto(sessao, 'probabilidade_prolongada', unidade: '%'),
            ),

          if (temAmbiente) ...[
            const Divider(),
            subtitulo('O ambiente enquanto você jogava'),

            if (sessao['temperatura'] != null)
              linha(
                'Temperatura',
                dadoTexto(sessao, 'temperatura', unidade: ' °C'),
              ),

            if (sessao['umidade'] != null)
              linha(
                'Umidade do ar',
                dadoTexto(sessao, 'umidade', unidade: '%'),
              ),

            if (sessao['luminosidade'] != null)
              linha(
                'Iluminação',
                dadoTexto(sessao, 'luminosidade', unidade: ' lux'),
              ),

            if (sessao['ruido_db'] != null)
              linha(
                'Barulho ao redor',
                dadoTexto(sessao, 'ruido_db', unidade: ' dB'),
              ),
          ],

          const Divider(),

          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: destaque),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Uma dica para você',
                  style: TextStyle(
                    color: destaque,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            dicaJogador(sessao['recomendacao']),
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 23. SEU TEMPO DE JOGO
  // ==========================================================

  Widget painelEstatistico(
    String plataforma,
    List<Map<String, dynamic>> dados,
  ) {
    final stats = EstatisticasSessoes.calcular(dados);

    return cartao(
      'Seu tempo de jogo • $plataforma',
      Column(
        children: [
          linha('Partidas jogadas', '${stats.quantidade}'),
          linha('Tempo jogado', duracaoTexto(stats.total)),
          linha('Tempo médio por partida', '${numeroBR(stats.media)} min'),
          linha('Seu tempo habitual', '${numeroBR(stats.mediana)} min'),
          linha('Variação entre partidas', '${numeroBR(stats.desvio)} min'),
          linha('Partida mais curta', '${numeroBR(stats.minimo)} min'),
          linha('Partida mais longa', '${numeroBR(stats.maximo)} min'),
          linha('Pausas feitas', '${stats.pausas}'),
          linha('Partidas com pausas', '${stats.comPausas}'),
          linha('Partidas sem pausas', '${stats.semPausas}'),
        ],
      ),
    );
  }

  // ==========================================================
  // 24. MEU RITMO
  // ==========================================================

  Widget telaAnalise() {
    if (sessoes.isEmpty) {
      return cartao(
        'Suas partidas',
        const Text('Você ainda não tem partidas registradas.'),
      );
    }

    final pc = sessoes.where((s) {
      return s['plataforma']?.toString().toLowerCase() == 'pc';
    }).toList();

    final android = sessoes.where((s) {
      return s['plataforma']?.toString().toLowerCase() == 'android';
    }).toList();

    final avaliadas = sessoes.where(possuiAnaliseDetalhada).toList();

    final acompanhadas = sessoes.where((s) {
      return s['classificacao'] != null && !possuiAnaliseDetalhada(s);
    }).toList();

    final aguardando = sessoes.where((s) {
      return s['classificacao'] == null && !possuiAnaliseDetalhada(s);
    }).toList();

    return Column(
      children: [
        cartao(
          'Como anda seu tempo de jogo?',
          const Text(
            'Descubra quanto você costuma jogar, '
            'quantas pausas faz e como estão suas partidas.',
          ),
        ),

        cartao(
          'Suas partidas',
          Column(
            children: [
              linha('Partidas registradas', '${sessoes.length}'),
              linha('Partidas avaliadas', '${avaliadas.length}'),
              linha('Partidas acompanhadas', '${acompanhadas.length}'),
              linha('Aguardando avaliação', '${aguardando.length}'),
            ],
          ),
        ),

        painelEstatistico('Computador', pc),
        painelEstatistico('Celular', android),

        cartao(
          'Como foram suas partidas',
          Text(
            '${avaliadas.length} partidas possuem '
            'mais informações sobre seu tempo '
            'de jogo e seus hábitos.',
          ),
        ),

        for (final sessao in avaliadas) resultadoSalvoSupabase(sessao),

        cartao(
          'Suas outras partidas',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${acompanhadas.length} partidas '
                'já têm informações sobre seu ritmo.',
              ),
              const SizedBox(height: 12),
              for (final sessao in acompanhadas)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.gamepad_outlined, color: destaque),
                  title: Text('Partida ${sessao['id_fato']}'),
                  subtitle: Text(
                    '${duracaoTexto(decimal(sessao['duracao_minutos']))}'
                    ' • '
                    '${classificacaoJogador(sessao['classificacao'])}',
                  ),
                ),
            ],
          ),
        ),

        if (aguardando.isNotEmpty)
          cartao(
            'Partidas aguardando avaliação',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estas partidas já foram registradas, '
                  'mas ainda não foram avaliadas.',
                ),
                for (final sessao in aguardando)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.schedule, color: destaque),
                    title: Text('Partida ${sessao['id_fato']}'),
                    subtitle: Text(nomeJogoHistorico(sessao)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ==========================================================
  // 25. MINHAS PARTIDAS
  // ==========================================================

  Widget telaHistorico() {
    return Column(
      children: [
        cartao(
          'Suas partidas',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Partidas encontradas: ${sessoes.length}'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: atualizandoTudo ? null : atualizarTudo,
                icon: const Icon(Icons.sync),
                label: const Text('Atualizar minhas partidas'),
              ),
            ],
          ),
        ),

        if (sessoes.isEmpty)
          cartao(
            'Nenhuma partida por aqui',
            const Text(
              'Quando você jogar usando o ANHANGÁ, '
              'suas partidas aparecerão aqui.',
            ),
          ),

        for (final sessao in sessoes)
          cartao(
            'Partida ${sessao['id_fato']}',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sports_esports, color: destaque),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nomeJogoHistorico(sessao),
                        style: TextStyle(
                          color: destaque,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Text(
                  'Onde jogou: '
                  '${nomePlataforma(sessao['plataforma'])}',
                ),

                Text(
                  'Tempo jogado: '
                  '${duracaoTexto(sessao['duracao_minutos'] == null ? null : decimal(sessao['duracao_minutos']))}',
                ),

                Text(
                  'Pausas feitas: '
                  '${inteiro(sessao['quantidade_pausas'])}',
                ),

                if (sessao['limite_minutos_sessao'] != null)
                  Text(
                    'Tempo escolhido: '
                    '${duracaoTexto(decimal(sessao['limite_minutos_sessao']))}',
                  ),

                Text('Começou: ${dataTexto(sessao['inicio'])}'),

                Text('Terminou: ${dataTexto(sessao['fim'])}'),

                Text(
                  'Seu ritmo: '
                  '${classificacaoJogador(sessao['classificacao'])}',
                ),

                if (sessao['probabilidade_prolongada'] != null)
                  Text(
                    'Risco registrado de passar do tempo: '
                    '${dadoTexto(sessao, 'probabilidade_prolongada', unidade: '%')}',
                  ),

                if (sessao['recomendacao'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Dica: ${dicaJogador(sessao['recomendacao'])}'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ==========================================================
  // 26. AJUSTES
  // ==========================================================

  Widget telaPreferencias() {
    return Column(
      children: [
        cartao(
          'Deixe o ANHANGÁ do seu jeito',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text('Cores com mais contraste'),
                subtitle: const Text(
                  'Deixa os textos e destaques mais fáceis de ver.',
                ),
                value: altoContraste,
                onChanged: (valor) {
                  setState(() {
                    altoContraste = valor;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: paleta,
                decoration: const InputDecoration(
                  labelText: 'Cores do aplicativo',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Padrão',
                    child: Text('Cores originais'),
                  ),
                  DropdownMenuItem(
                    value: 'Protanopia',
                    child: Text('Paleta para protanopia'),
                  ),
                  DropdownMenuItem(
                    value: 'Deuteranopia',
                    child: Text('Paleta para deuteranopia'),
                  ),
                  DropdownMenuItem(
                    value: 'Tritanopia',
                    child: Text('Paleta para tritanopia'),
                  ),
                  DropdownMenuItem(
                    value: 'Acromatopsia',
                    child: Text('Tons de cinza'),
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
                'As opções de cores ajudam na personalização '
                'e não substituem uma avaliação individual '
                'de acessibilidade.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
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
  // 27. INTERFACE PRINCIPAL
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    const titulos = [
      'Início',
      'Meus jogos',
      'Meu ritmo',
      'Minhas partidas',
      'Configurações',
    ];

    const rotulos = ['Início', 'Jogos', 'Meu ritmo', 'Partidas', 'Ajustes'];

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
        'Não conseguimos carregar suas partidas',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Confira sua conexão e tente novamente.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: atualizarTudo,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    } else {
      switch (pagina) {
        case 0:
          conteudo = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ABRIR_AGENDA_INTELIGENTE_ANHANGA
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AgendaInteligente()),
                ),
                icon: const Icon(Icons.calendar_month),
                label: const Text('Agenda Inteligente'),
              ),
              const SizedBox(height: 12),
              telaPainel(),
            ],
          );
          break;
        case 1:
          conteudo = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ABRIR_PERFIL_GAMER_ANHANGA
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PerfilGamerJogos(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.sports_esports),
                    label: const Text('Sincronizar jogos instalados'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              telaJogos(),
            ],
          );
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
              'SEU COMPANHEIRO DE JOGO',
              style: TextStyle(fontSize: 10, letterSpacing: 1),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar minhas partidas',
            onPressed: atualizarTudo,
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Sair da conta',
            onPressed: () async {
              await supabase.auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: atualizarTudo,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              titulos[pagina],
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            conteudo,
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: pagina,
        onDestinationSelected: (indice) {
          setState(() {
            pagina = indice;
          });
        },
        destinations: List.generate(
          rotulos.length,
          (indice) => NavigationDestination(
            icon: Icon(icones[indice]),
            label: rotulos[indice],
          ),
        ),
      ),
    );
  }
}
