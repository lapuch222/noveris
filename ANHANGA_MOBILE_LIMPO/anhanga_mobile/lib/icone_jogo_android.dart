import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';

class IconeJogoAndroid extends StatelessWidget {
  const IconeJogoAndroid({
    super.key,
    required this.pacote,
    required this.cor,
    this.tamanho = 36,
  });

  final String? pacote;
  final Color cor;
  final double tamanho;

  // Carrega uma unica vez e compartilha os icones.
  static Future<Map<String, Uint8List>>? _cache;

  static Future<Map<String, Uint8List>> _carregar() async {
    final resultado = <String, Uint8List>{};

    try {
      final apps = await InstalledApps.getInstalledApps(
        withIcon: true,
        excludeSystemApps: true,
        excludeNonLaunchableApps: true,
      );

      for (final app in apps) {
        if (app.icon != null && app.icon!.isNotEmpty) {
          resultado[app.packageName] = app.icon!;
        }
      }
    } catch (e) {
      debugPrint('ANHANGA: erro ao obter icones: $e');
    }

    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    final nomePacote = pacote?.trim() ?? '';

    Widget reserva() {
      return Icon(
        Icons.sports_esports_outlined,
        color: cor,
        size: tamanho * 0.8,
      );
    }

    if (nomePacote.isEmpty) return reserva();

    return FutureBuilder<Map<String, Uint8List>>(
      future: _cache ??= _carregar(),
      builder: (context, snapshot) {
        final bytes = snapshot.data?[nomePacote];

        if (bytes == null || bytes.isEmpty) {
          return reserva();
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.memory(
            bytes,
            width: tamanho,
            height: tamanho,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => reserva(),
          ),
        );
      },
    );
  }
}
