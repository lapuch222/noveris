import 'package:flutter/material.dart';

class IconeJogoPc extends StatelessWidget {
  const IconeJogoPc({
    super.key,
    required this.nome,
    required this.cor,
    required this.fallback,
    this.tamanho = 38,
  });

  final String nome;
  final Color cor;
  final Widget fallback;
  final double tamanho;

  static const imagens = <String, String>{
    'anotherdoor': 'another_door.jpg',
    'enterthegungeon': 'enter_the_gungeon.jpg',
    'musedash': 'muse_dash.jpg',
    'paladins': 'paladins.jpg',
  };

  String normalizar(String nome) {
    return nome.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  @override
  Widget build(BuildContext context) {
    final chave = normalizar(nome);

    // Nao misturar versoes mobile com artes de PC.
    if (chave == 'grandchase' ||
        chave == 'grandchasemobile' ||
        chave == 'diabloimmortal') {
      return fallback;
    }

    final arquivo = imagens[chave];

    if (arquivo == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/icons/jogos/$arquivo',
        width: tamanho,
        height: tamanho,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Imagem nao carregada: $arquivo');
          return fallback;
        },
      ),
    );
  }
}
