import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// ANHANGÁ — CONTROLE DO QUARTO VIRTUAL
//
// Abas:
// 1. Luz
// 2. Ambiente
// 3. Jogador
//
// Comunicação com o HTML:
// Canal: quarto:CODIGO
// Evento: estado
//
// Os controles manuais são uma simulação.
// Nenhuma medição é inventada ou salva como real.
// ============================================================

class QuartoVirtualPage extends StatefulWidget {
  const QuartoVirtualPage({super.key, required this.sessoes});

  final List<Map<String, dynamic>> sessoes;

  @override
  State<QuartoVirtualPage> createState() => _QuartoVirtualPageState();
}

class _QuartoVirtualPageState extends State<QuartoVirtualPage> {
  static const destaque = Color(0xFF5FD4EC);
  static const fundo = Color(0xFF04090D);
  static const painel = Color(0xFF0A1720);

  final codigoController = TextEditingController();

  bool lampadaLigada = false;
  double intensidadeLuz = 70;

  // Condições simuladas pelo usuário.
  double temperatura = 24;
  double ruido = 40;
  double umidade = 50;

  String personagem = 'adulto';

  // Permite escolher uma sessão real do histórico
  // em vez de valores configurados manualmente.
  int? indiceHistorico;

  bool enviando = false;
  bool salvando = false;
  bool _mudancaPendente = false;
  Timer? _timerEnvio;

  String mensagem = 'Digite o código exibido no quarto.';

  String get codigo {
    return codigoController.text.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
  }

  List<Map<String, dynamic>> get sessoesComAmbiente {
    return widget.sessoes.where((sessao) {
      return sessao['temperatura'] != null ||
          sessao['umidade'] != null ||
          sessao['ruido_db'] != null;
    }).toList();
  }

  double? converterNumero(Object? valor) {
    if (valor == null) return null;

    if (valor is num) {
      return valor.toDouble();
    }

    return double.tryParse(valor.toString().replaceAll(',', '.'));
  }

  String nomePersonagem(String valor) {
    switch (valor) {
      case 'crianca':
        return 'Criança';
      case 'adolescente':
        return 'Adolescente';
      default:
        return 'Adulto';
    }
  }

  String situacaoTemperatura() {
    if (temperatura < 19) {
      return 'Está bem frio!';
    }

    if (temperatura < 22) {
      return 'Um pouco frio';
    }

    if (temperatura < 27) {
      return 'Temperatura agradável';
    }

    if (temperatura < 30) {
      return 'Está ficando quente';
    }

    return 'Muito quente!';
  }

  String situacaoRuido() {
    if (ruido < 20) {
      return 'Quarto bem silencioso';
    }

    if (ruido < 45) {
      return 'Ambiente tranquilo';
    }

    if (ruido < 70) {
      return 'Barulho moderado';
    }

    if (ruido < 85) {
      return 'Ambiente barulhento';
    }

    return 'Barulho muito alto!';
  }

  @override
  void dispose() {
    _timerEnvio?.cancel();
    codigoController.dispose();
    super.dispose();
  }

  // ==========================================================
  // ENVIAR CONTROLES PARA O QUARTO
  // ==========================================================

  // ===================================================
  // ENVIO AUTOMATICO
  // ===================================================

  void agendarEnvio() {
    if (codigo.length != 6) return;

    _timerEnvio?.cancel();

    _timerEnvio = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;

      if (enviando) {
        _mudancaPendente = true;
        return;
      }

      enviarAoQuarto();
    });
  }

  // ===================================================
  // ESTADO PARA RECOMENDACOES E SALVAMENTO
  // ===================================================

  Map<String, dynamic> get configuracaoAtual {
    Map<String, dynamic>? sessao;

    final historico = sessoesComAmbiente;

    if (indiceHistorico != null &&
        indiceHistorico! >= 0 &&
        indiceHistorico! < historico.length) {
      sessao = historico[indiceHistorico!];
    }

    return {
      'temperatura': sessao == null
          ? temperatura
          : converterNumero(sessao['temperatura']),
      'umidade': sessao == null ? umidade : converterNumero(sessao['umidade']),
      'ruido_db': sessao == null ? ruido : converterNumero(sessao['ruido_db']),
    };
  }

  List<String> get recomendacoes {
    final dados = configuracaoAtual;
    final dicas = <String>[];

    final t = dados['temperatura'] as double?;
    final r = dados['ruido_db'] as double?;
    final u = dados['umidade'] as double?;

    if (t != null) {
      if (t > 28) {
        dicas.add(
          'O quarto esta quente. Considere '
          'melhorar a ventilacao.',
        );
      } else if (t < 20) {
        dicas.add(
          'O quarto esta frio. Considere '
          'ajustar o conforto termico.',
        );
      }
    }

    if (r != null && r >= 70) {
      dicas.add(
        'O nivel de ruido esta alto. '
        'Que tal reduzir o volume?',
      );
    }

    if (u != null) {
      if (u < 30) {
        dicas.add('A umidade simulada esta baixa.');
      } else if (u > 70) {
        dicas.add(
          'A umidade simulada esta alta. '
          'Considere ventilar o ambiente.',
        );
      }
    }

    if (lampadaLigada && intensidadeLuz > 85) {
      dicas.add(
        'A luz esta muito intensa. '
        'Experimente diminuir o brilho.',
      );
    }

    if (dicas.isEmpty) {
      dicas.add(
        'Nenhum alerta de conforto pelas '
        'regras atuais do quarto.',
      );
    }

    return dicas;
  }

  // ===================================================
  // SALVAR CONFIGURACOES NO SUPABASE
  // ===================================================

  Future<void> salvarConfiguracao() async {
    if (salvando) return;

    final cliente = Supabase.instance.client;
    final usuario = cliente.auth.currentUser;

    if (usuario == null) {
      setState(() {
        mensagem = 'Entre na sua conta para salvar.';
      });
      return;
    }

    if (codigo.length != 6) {
      setState(() {
        mensagem = 'Digite o codigo do quarto.';
      });
      return;
    }

    final dados = configuracaoAtual;

    if (dados['temperatura'] == null ||
        dados['umidade'] == null ||
        dados['ruido_db'] == null) {
      setState(() {
        mensagem =
            'Esta partida nao possui todos os dados '
            'ambientais. Use os controles manuais.';
      });
      return;
    }

    setState(() {
      salvando = true;
      mensagem = 'Salvando suas preferências...';
    });

    try {
      await cliente.from('quarto_virtual_config').insert({
        'auth_user_id': usuario.id,
        'codigo_quarto': codigo,
        'personagem': personagem,
        'lampada_ligada': lampadaLigada,
        'intensidade_luz': lampadaLigada ? intensidadeLuz.round() : 0,
        'temperatura': dados['temperatura'],
        'umidade': dados['umidade'],
        'ruido_db': dados['ruido_db'],
        'recomendacoes': recomendacoes,
        'origem': indiceHistorico == null
            ? 'simulacao_manual'
            : 'historico_partida',
      });

      if (!mounted) return;

      setState(() {
        mensagem = 'Preferências salvas com sucesso!';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        mensagem = 'Erro ao salvar: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          salvando = false;
        });
      }
    }
  }

  Future<void> enviarAoQuarto() async {
    if (enviando) {
      _mudancaPendente = true;
      return;
    }

    final codigoAtual = codigo;

    if (codigoAtual.length != 6) {
      setState(() {
        mensagem = 'Digite os 6 caracteres do código do quarto.';
      });
      return;
    }

    setState(() {
      enviando = true;
      mensagem = 'Conectando ao quarto...';
    });

    RealtimeChannel? canal;

    try {
      final supabase = Supabase.instance.client;

      canal = supabase.channel('quarto:$codigoAtual');

      final conectado = Completer<void>();

      canal.subscribe((status, error) {
        if (conectado.isCompleted) return;

        if (status == RealtimeSubscribeStatus.subscribed) {
          conectado.complete();
        } else if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut ||
            status == RealtimeSubscribeStatus.closed) {
          conectado.completeError(
            error ?? Exception('Não foi possível conectar.'),
          );
        }
      });

      await conectado.future.timeout(const Duration(seconds: 12));

      final historico = sessoesComAmbiente;

      Map<String, dynamic>? sessaoEscolhida;

      if (indiceHistorico != null &&
          indiceHistorico! >= 0 &&
          indiceHistorico! < historico.length) {
        sessaoEscolhida = historico[indiceHistorico!];
      }

      final dados = <String, dynamic>{
        'pessoa': personagem,

        'lampada_ligada': lampadaLigada,

        'intensidade_luz': lampadaLigada ? intensidadeLuz.round() : 0,

        // Com histórico selecionado, usa somente
        // valores realmente salvos no banco.
        // Caso contrário, usa a simulação manual.
        'temperatura': sessaoEscolhida == null
            ? temperatura
            : converterNumero(sessaoEscolhida['temperatura']),

        'umidade': sessaoEscolhida == null
            ? umidade
            : converterNumero(sessaoEscolhida['umidade']),

        'ruido_db': sessaoEscolhida == null
            ? ruido
            : converterNumero(sessaoEscolhida['ruido_db']),
      };

      final resultado = await canal.sendBroadcastMessage(
        event: 'estado',
        payload: dados,
      );

      debugPrint('ANHANGA - Canal: quarto:$codigoAtual');
      debugPrint('ANHANGA - Dados enviados: $dados');
      debugPrint('ANHANGA - Resposta do envio: $resultado');

      if (resultado != ChannelResponse.ok) {
        throw Exception('Servidor nao confirmou o envio: $resultado');
      }

      if (!mounted) return;

      setState(() {
        mensagem =
            'Envio confirmado pelo servidor. '
            'Confira o quarto no navegador.';
      });
    } on TimeoutException {
      if (mounted) {
        setState(() {
          mensagem =
              'A conexão demorou muito. '
              'Confira a internet e o código.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          mensagem = 'Não foi possível enviar: $e';
        });
      }
    } finally {
      if (canal != null) {
        await Supabase.instance.client.removeChannel(canal);
      }

      if (mounted) {
        setState(() {
          enviando = false;
        });

        if (_mudancaPendente) {
          _mudancaPendente = false;
          agendarEnvio();
        }
      }
    }
  }

  // ==========================================================
  // COMPONENTES VISUAIS
  // ==========================================================

  Widget cartao(String titulo, Widget conteudo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: painel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1B3B4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: destaque,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          conteudo,
        ],
      ),
    );
  }

  Widget controleDeslizante({
    required String titulo,
    required String unidade,
    required double valor,
    required double minimo,
    required double maximo,
    required ValueChanged<double> aoAlterar,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(titulo, style: const TextStyle(fontSize: 16))),
            Text(
              '${valor.round()}$unidade',
              style: const TextStyle(
                color: destaque,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: valor,
          min: minimo,
          max: maximo,
          activeColor: destaque,
          onChanged: aoAlterar,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${minimo.round()}$unidade',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            Text(
              '${maximo.round()}$unidade',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================================
  // ABA 1 — LUZ
  // ==========================================================

  Widget abaLuz() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        cartao(
          'Iluminação do quarto',
          Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: lampadaLigada,
                activeThumbColor: destaque,
                onChanged: (valor) {
                  setState(() {
                    lampadaLigada = valor;
                    agendarEnvio();
                  });
                },
                secondary: Icon(
                  lampadaLigada ? Icons.lightbulb : Icons.lightbulb_outline,
                  color: destaque,
                  size: 32,
                ),
                title: const Text('Lâmpada virtual'),
                subtitle: Text(lampadaLigada ? 'Ligada' : 'Desligada'),
              ),

              const SizedBox(height: 20),

              controleDeslizante(
                titulo: 'Brilho da lâmpada',
                unidade: '%',
                valor: intensidadeLuz,
                minimo: 0,
                maximo: 100,
                aoAlterar: (valor) {
                  setState(() {
                    intensidadeLuz = valor;
                    agendarEnvio();
                  });
                },
              ),

              const SizedBox(height: 8),

              const Text(
                'Altere o brilho para deixar '
                'o quarto mais claro ou escuro.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // ABA 2 — AMBIENTE
  // ==========================================================

  Widget abaAmbiente() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        cartao(
          'Recomendacoes do ANHANGA',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final dica in recomendacoes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.tips_and_updates_outlined,
                        color: destaque,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(dica)),
                    ],
                  ),
                ),
              const Text(
                'Sugestoes baseadas em regras simples '
                'de conforto. Nao sao medicoes ao vivo.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        cartao(
          'Temperatura do quarto',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Escolha a temperatura que deseja '
                'simular no quarto gamer.',
              ),

              const SizedBox(height: 22),

              controleDeslizante(
                titulo: 'Temperatura',
                unidade: ' °C',
                valor: temperatura,
                minimo: 16,
                maximo: 35,
                aoAlterar: (valor) {
                  setState(() {
                    temperatura = valor;
                    agendarEnvio();
                    indiceHistorico = null;
                  });
                },
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(Icons.thermostat, color: destaque),
                  const SizedBox(width: 10),
                  Expanded(child: Text(situacaoTemperatura())),
                ],
              ),
            ],
          ),
        ),

        cartao(
          'Barulho do quarto',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Simule um ambiente silencioso '
                'ou com mais barulho.',
              ),

              const SizedBox(height: 22),

              controleDeslizante(
                titulo: 'Nível de ruído',
                unidade: ' dB',
                valor: ruido,
                minimo: 0,
                maximo: 110,
                aoAlterar: (valor) {
                  setState(() {
                    ruido = valor;
                    agendarEnvio();
                    indiceHistorico = null;
                  });
                },
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(Icons.graphic_eq, color: destaque),
                  const SizedBox(width: 10),
                  Expanded(child: Text(situacaoRuido())),
                ],
              ),
            ],
          ),
        ),

        cartao(
          'Umidade do ar',
          Column(
            children: [
              controleDeslizante(
                titulo: 'Umidade',
                unidade: '%',
                valor: umidade,
                minimo: 0,
                maximo: 100,
                aoAlterar: (valor) {
                  setState(() {
                    umidade = valor;
                    agendarEnvio();
                    indiceHistorico = null;
                  });
                },
              ),

              const SizedBox(height: 12),

              const Text(
                'A umidade também pode mudar '
                'os efeitos visuais do quarto.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),

        cartao(
          'Usar dados de uma partida',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Opcional: em vez dos valores '
                'simulados acima, escolha uma '
                'partida com dados ambientais salvos.',
              ),

              const SizedBox(height: 14),

              DropdownButtonFormField<int>(
                key: ValueKey(indiceHistorico),
                initialValue: indiceHistorico,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Partida registrada',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int>(
                    value: -1,
                    child: Text('Usar controles manuais'),
                  ),
                  for (int i = 0; i < sessoesComAmbiente.length; i++)
                    DropdownMenuItem<int>(
                      value: i,
                      child: Text(
                        'Partida '
                        '${sessoesComAmbiente[i]['id_fato']}',
                      ),
                    ),
                ],
                onChanged: (indice) {
                  setState(() {
                    indiceHistorico = indice == null || indice == -1
                        ? null
                        : indice;
                  });
                },
              ),

              if (indiceHistorico != null)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Os valores enviados serão os '
                    'da partida selecionada.',
                    style: TextStyle(color: destaque),
                  ),
                ),

              const SizedBox(height: 12),

              const Text(
                'Os controles manuais representam '
                'uma simulação, não medições reais.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // ABA 3 — JOGADOR
  // ==========================================================

  Widget abaJogador() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        cartao(
          'Quem está jogando?',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Escolha qual personagem aparece '
                'na cadeira do quarto.',
              ),

              const SizedBox(height: 18),

              RadioGroup<String>(
                groupValue: personagem,
                onChanged: (valor) {
                  if (valor != null) {
                    setState(() {
                      personagem = valor;
                      agendarEnvio();
                    });
                  }
                },
                child: const Column(
                  children: [
                    RadioListTile<String>(
                      title: Text('Criança'),
                      secondary: Icon(Icons.child_care),
                      value: 'crianca',
                    ),
                    RadioListTile<String>(
                      title: Text('Adolescente'),
                      secondary: Icon(Icons.person_outline),
                      value: 'adolescente',
                    ),
                    RadioListTile<String>(
                      title: Text('Adulto'),
                      secondary: Icon(Icons.person),
                      value: 'adulto',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Personagem escolhido: '
                '${nomePersonagem(personagem)}',
                style: const TextStyle(
                  color: destaque,
                  fontWeight: FontWeight.bold,
                ),
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: fundo,

        appBar: AppBar(
          backgroundColor: const Color(0xFF08151D),
          title: const Text('Meu Quarto'),
          bottom: const TabBar(
            indicatorColor: destaque,
            labelColor: destaque,
            tabs: [
              Tab(icon: Icon(Icons.lightbulb_outline), text: 'Luz'),
              Tab(icon: Icon(Icons.thermostat), text: 'Ambiente'),
              Tab(icon: Icon(Icons.person_outline), text: 'Jogador'),
            ],
          ),
        ),

        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: codigoController,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Código do quarto',
                  hintText: 'Ex.: ABC123',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
              ),
            ),

            Expanded(
              child: TabBarView(
                children: [abaLuz(), abaAmbiente(), abaJogador()],
              ),
            ),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF08151D),
                border: Border(top: BorderSide(color: Color(0xFF1B3B4A))),
              ),
              child: Column(
                children: [
                  FilledButton.icon(
                    onPressed: enviando ? null : enviarAoQuarto,
                    icon: const Icon(Icons.send),
                    label: Text(
                      enviando ? 'Enviando...' : 'Atualizar meu quarto',
                    ),
                  ),

                  OutlinedButton.icon(
                    onPressed: salvando ? null : salvarConfiguracao,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      salvando ? 'Salvando...' : 'Salvar minhas preferências',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    mensagem,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: destaque, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
