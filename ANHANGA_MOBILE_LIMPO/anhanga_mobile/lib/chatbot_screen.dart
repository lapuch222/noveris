import 'anhanga_v6_tools.dart';
import 'estatisticas_chat_v4.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ANHANGÁ AI Assistant V3 - histórico por usuário no Supabase.
/// A Edge Function chat-anhanga permanece responsável pela IA e por buscar
/// somente as partidas autorizadas do jogador.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  static const _azul = Color(0xFF5FD4EC);
  final _texto = TextEditingController();
  final _rolagem = ScrollController();
  final List<Map<String, String>> _mensagens = [];
  bool _carregando = true;
  bool _enviando = false;
  bool _consentimento = false;
  String? _aviso;

  SupabaseClient get _cliente => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  @override
  void dispose() {
    _texto.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  void _rolarAteFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _rolagem.hasClients) {
        _rolagem.animateTo(
          _rolagem.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _carregarHistorico() async {
    final userId = _cliente.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _aviso = 'Entre na sua conta para acessar a conversa.';
        });
      }
      return;
    }
    try {
      final rows = await _cliente
          .from('anhanga_chat_mensagens')
          .select('papel,conteudo')
          .eq('auth_user_id', userId)
          .order('id', ascending: false)
          .limit(80);
      if (!mounted || _cliente.auth.currentUser?.id != userId) {
        return;
      }
      setState(() {
        _mensagens
          ..clear()
          ..addAll(
            rows.reversed.map(
              (r) => {
                'role': r['papel'].toString(),
                'content': r['conteudo'].toString(),
              },
            ),
          );
        _carregando = false;
        _aviso = null;
      });
      _rolarAteFim();
    } catch (_) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _aviso = 'Não foi possível carregar o histórico. Tente novamente.';
        });
      }
    }
  }

  Future<void> _salvarMensagem(String role, String content, String uid) async {
    await _cliente.from('anhanga_chat_mensagens').insert({
      'auth_user_id': uid,
      'papel': role,
      'conteudo': content,
    });
  }

  Future<void> _enviar([String? sugestao]) async {
    final pergunta = (sugestao ?? _texto.text).trim();
    if (_enviando || _carregando || pergunta.isEmpty) {
      return;
    }
    if (!_consentimento) {
      setState(
        () => _aviso =
            'Marque a autorização para consultar suas partidas pela IA.',
      );
      return;
    }
    if (pergunta.length > 1500) {
      setState(() => _aviso = 'A pergunta deve ter até 1.500 caracteres.');
      return;
    }
    final userId = _cliente.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _aviso = 'Entre na sua conta novamente.');
      return;
    }

    final historico = _mensagens.length > 8
        ? _mensagens.sublist(_mensagens.length - 8)
        : List<Map<String, String>>.from(_mensagens);
    setState(() {
      _enviando = true;
      _aviso = null;
      _mensagens.add({'role': 'user', 'content': pergunta});
      _texto.clear();
    });
    _rolarAteFim();

    try {
      await _salvarMensagem('user', pergunta, userId);
      final resultado = await _cliente.functions.invoke(
        'chat-anhanga',
        body: {'mensagem': pergunta, 'historico': historico},
      );
      if (_cliente.auth.currentUser?.id != userId) {
        return;
      }
      final dados = resultado.data;
      if (dados is! Map || dados['resposta'] is! String) {
        throw Exception('A IA não retornou uma resposta válida.');
      }
      final resposta = (dados['resposta'] as String).trim();
      if (resposta.isEmpty) {
        throw Exception('A IA respondeu com uma mensagem vazia.');
      }
      await _salvarMensagem('assistant', resposta, userId);
      if (!mounted) {
        return;
      }
      setState(
        () => _mensagens.add({'role': 'assistant', 'content': resposta}),
      );
      _rolarAteFim();
    } catch (e) {
      if (mounted) {
        setState(
          () => _aviso = 'Não foi possível concluir a resposta. Confira sua conexão e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _limparHistorico() async {
    final userId = _cliente.auth.currentUser?.id;
    if (userId == null || _enviando) {
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar conversa?'),
        content: const Text(
          'As mensagens salvas deste jogador serão excluídas. As partidas e análises não serão apagadas.',
        ),
        actions: [
          const AnHangaPdfV6(),
          IconButton(
            tooltip: 'Alerta de tempo V6',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AnHangaAlertaV6()),
            ),
          ),
          IconButton(
            tooltip: 'Ver estatÃ­sticas e grÃ¡ficos',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EstatisticasChatV4()),
            ),
            icon: const Icon(Icons.bar_chart),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) {
      return;
    }
    setState(() => _carregando = true);
    try {
      await _cliente
          .from('anhanga_chat_mensagens')
          .delete()
          .eq('auth_user_id', userId);
      if (!mounted || _cliente.auth.currentUser?.id != userId) {
        return;
      }
      setState(() {
        _mensagens.clear();
        _aviso = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _aviso = 'Não foi possível apagar as mensagens.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ANHANGÁ AI Assistant'),
        backgroundColor: const Color(0xFF08151D),
        actions: [
          const AnHangaPdfV6(),
          IconButton(
            tooltip: 'Alerta de tempo V6',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AnHangaAlertaV6()),
            ),
          ),
          IconButton(
            tooltip: 'Ver estatÃ­sticas e grÃ¡ficos',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EstatisticasChatV4()),
            ),
            icon: const Icon(Icons.bar_chart),
          ),
          IconButton(
            tooltip: 'Apagar histórico de conversas',
            onPressed: _enviando || _carregando ? null : _limparHistorico,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            CheckboxListTile(
              value: _consentimento,
              onChanged: _enviando
                  ? null
                  : (v) => setState(() => _consentimento = v ?? false),
              title: const Text(
                'Autorizo o envio de um resumo das minhas partidas para a IA externa.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _atalho('Última partida', 'Qual foi minha última partida?'),
                  _atalho(
                    'Tempo jogado',
                    'Quanto tempo joguei nas sessões consultadas?',
                  ),
                  _atalho('Pausas', 'Quantas pausas registrei?'),
                  _atalho(
                    'Top jogos',
                    'Quais jogos tiveram mais tempo de uso nas sessões consultadas?',
                  ),
                  _atalho(
                    'Minha análise',
                    'Explique a classificação e o risco da minha última partida.',
                  ),
                ],
              ),
            ),
            if (_aviso != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _aviso!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
            if (_carregando) const LinearProgressIndicator(),
            Expanded(
              child: _mensagens.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Olá! Pergunte sobre suas partidas, pausas e jogos. Seu histórico será carregado ao voltar.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _rolagem,
                      padding: const EdgeInsets.all(12),
                      itemCount: _mensagens.length,
                      itemBuilder: (context, i) {
                        final m = _mensagens[i];
                        final usuario = m['role'] == 'user';
                        return Align(
                          alignment: usuario
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Card(
                            color: usuario
                                ? const Color(0xFF173F51)
                                : const Color(0xFF102431),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(m['content'] ?? ''),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_enviando) const LinearProgressIndicator(color: _azul),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _texto,
                      enabled: !_enviando && !_carregando,
                      maxLength: 1500,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Pergunte ao ANHANGÁ...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _enviar(),
                    ),
                  ),
                AnHangaVozV6(
                  enabled: !_enviando && !_carregando,
                  onRecognized: (textoReconhecido) {
                    if (mounted) setState(() => _texto.text = textoReconhecido);
                  },
                ),
                  IconButton(
                    tooltip: 'Enviar pergunta',
                    onPressed: _enviando || _carregando
                        ? null
                        : () => _enviar(),
                    icon: const Icon(Icons.send, color: _azul),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _atalho(String titulo, String pergunta) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ActionChip(
      label: Text(titulo),
      onPressed: _enviando || _carregando ? null : () => _enviar(pergunta),
    ),
  );
}

