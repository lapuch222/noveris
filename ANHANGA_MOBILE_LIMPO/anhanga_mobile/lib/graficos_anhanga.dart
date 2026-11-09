import 'dart:math' as math;
 
import 'package:flutter/material.dart';
 
const _corTexto = Color(0xFFB7CBD4);
const _corGrade = Color(0xFF344A55);
const _corEixo = Color(0xFF809AA7);
const _corFundoCartao = Color(0xFF0A1720);
 
// ------------------------------------------------------------
// Cores dos gráficos por paleta (as mesmas lógicas do HTML)
// ------------------------------------------------------------
 
class PaletaGraficos {
  const PaletaGraficos({
    required this.serie1,
    required this.serie2,
    required this.limite,
  });
 
  final Color serie1;
  final Color serie2;
  final Color limite;
 
  /// [destaque] é a cor que o painel já calcula para a paleta escolhida.
  factory PaletaGraficos.de({
    required String paleta,
    required bool altoContraste,
    required Color destaque,
  }) {
    if (altoContraste) {
      return PaletaGraficos(
        serie1: destaque,
        serie2: const Color(0xFF00FFFF),
        limite: Colors.white,
      );
    }
    switch (paleta) {
      case 'Protanopia':
        return PaletaGraficos(
          serie1: destaque,
          serie2: const Color(0xFFFFD23F),
          limite: Colors.white,
        );
      case 'Deuteranopia':
        return PaletaGraficos(
          serie1: destaque,
          serie2: const Color(0xFF56B4E9),
          limite: const Color(0xFFF0E442),
        );
      case 'Tritanopia':
        return PaletaGraficos(
          serie1: destaque,
          serie2: const Color(0xFF3DDC97),
          limite: const Color(0xFFF5F5F5),
        );
      case 'Acromatopsia':
        return PaletaGraficos(
          serie1: destaque,
          serie2: const Color(0xFF9A9A9A),
          limite: const Color(0xFFD0D0D0),
        );
      default:
        return PaletaGraficos(
          serie1: destaque,
          serie2: const Color(0xFF6FE3B0),
          limite: const Color(0xFFFFD166),
        );
    }
  }
}
 
// ------------------------------------------------------------
// Dado de uma sessão para os gráficos
// ------------------------------------------------------------
 
class PontoSessao {
  const PontoSessao({required this.id, required this.minutos, this.inicio});
 
  final int id;
  final double minutos;
  final DateTime? inicio;
 
  factory PontoSessao.deMapa(Map<String, dynamic> m) {
    double numero(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    return PontoSessao(
      id: numero(m['id_fato']).round(),
      minutos: numero(m['duracao_minutos']),
      inicio: DateTime.tryParse(m['inicio']?.toString() ?? '')?.toLocal(),
    );
  }
 
  String get data {
    final d = inicio;
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}';
  }
 
  String get rotulo => data.isEmpty ? '#$id' : '$data\n#$id';
  String get rotuloLinha => data.isEmpty ? '#$id' : '#$id · $data';
}
 
// ------------------------------------------------------------
// Utilidades
// ------------------------------------------------------------
 
String _duracao(num v) {
  final total = v.round();
  final h = total ~/ 60;
  final m = total % 60;
  return h == 0 ? '${m}min' : '${h}h ${m.toString().padLeft(2, '0')}min';
}
 
/// Escala com números "redondos" (1, 2, 5 x 10^n) e cerca de 4 intervalos.
/// Retorna [teto, passo].
List<double> _escala(double maior) {
  final alvo = math.max(maior, 1.0);
  final bruto = alvo / 4;
  final exp = math.pow(10, (math.log(bruto) / math.ln10).floor()).toDouble();
  final f = bruto / exp;
  final passo = (f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 5 ? 5 : 10))) * exp;
  final teto = (alvo / passo).ceil() * passo;
  return [teto.toDouble(), passo.toDouble()];
}
 
String _fraseResumo(
  List<PontoSessao> pontos,
  double? limite,
  String periodo,
) {
  final mais = pontos.reduce((a, b) => a.minutos >= b.minutos ? a : b);
  var texto =
      'Últimas ${pontos.length} sessões • $periodo. '
      'Sessão mais longa: ${_duracao(mais.minutos)} (#${mais.id}).';
  if (limite != null) {
    texto +=
        ' Limite configurado: ${_duracao(limite)}.';
  }
  return texto;
}
 
String _descricaoAcessivel(String tipo, List<PontoSessao> pontos) {
  final itens = pontos
      .map(
        (p) =>
            'sessão ${p.id}${p.data.isEmpty ? '' : ' em ${p.data}'}: '
            '${p.minutos.round()} minutos',
      )
      .join('; ');
  return '$tipo. Eixo vertical: duração em minutos. '
      'Eixo horizontal: sessões. $itens.';
}
 
void _texto(
  Canvas canvas,
  String texto,
  Offset ancora, {
  TextStyle estilo = const TextStyle(color: _corTexto, fontSize: 11),
  TextAlign alinhar = TextAlign.center,
  Alignment ref = Alignment.topCenter,
  double larguraMax = 140,
  Color? fundo,
}) {
  final tp = TextPainter(
    text: TextSpan(text: texto, style: estilo),
    textAlign: alinhar,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: larguraMax);
  final pos = ancora -
      Offset(tp.width * (ref.x + 1) / 2, tp.height * (ref.y + 1) / 2);
  if (fundo != null) {
    canvas.drawRect(
      Rect.fromLTWH(pos.dx, pos.dy, tp.width, tp.height).inflate(2),
      Paint()..color = fundo,
    );
  }
  tp.paint(canvas, pos);
}
 
void _tracejado(
  Canvas canvas,
  Offset a,
  Offset b,
  Paint pincel, {
  double traco = 6,
  double vazio = 4,
}) {
  final total = (b - a).distance;
  if (total <= 0) return;
  final dir = (b - a) / total;
  var d = 0.0;
  while (d < total) {
    final fim = math.min(d + traco, total);
    canvas.drawLine(a + dir * d, a + dir * fim, pincel);
    d += traco + vazio;
  }
}
 
void _hachura(Canvas canvas, Rect area, Color cor) {
  final linha = Paint()
    ..color = cor
    ..strokeWidth = 2;
  for (var x = area.left - area.height; x < area.right; x += 7) {
    canvas.drawLine(
      Offset(x, area.bottom),
      Offset(x + area.height, area.top),
      linha,
    );
  }
}
 
// ============================================================
// 1) BARRAS HORIZONTAIS — duração por sessão
// ============================================================
 
class GraficoHorizontalSessoes extends StatelessWidget {
  const GraficoHorizontalSessoes({
    super.key,
    required this.pontos,
    required this.paleta,
    required this.periodo,
    this.limite,
  });
 
  final List<PontoSessao> pontos;
  final PaletaGraficos paleta;
  final String periodo;
  final double? limite;
 
  @override
  Widget build(BuildContext context) {
    if (pontos.isEmpty) {
      return Text('Nenhuma sessão encontrada em: $periodo.');
    }
    final maior = math.max(
      pontos.map((p) => p.minutos).reduce(math.max),
      limite ?? 0.0,
    );
    final escala = _escala(maior);
    final altura = 30.0 + pontos.length * 42 + 62;
 
    return Semantics(
      label: _descricaoAcessivel('Gráfico de barras horizontais', pontos),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fraseResumo(pontos, limite, periodo),
            style: const TextStyle(fontSize: 12, color: _corTexto),
          ),
          const SizedBox(height: 12),
          ExcludeSemantics(
            child: SizedBox(
              width: double.infinity,
              height: altura,
              child: CustomPaint(
                painter: _HorizontalPainter(
                  pontos: pontos,
                  teto: escala[0],
                  passo: escala[1],
                  cor: paleta.serie1,
                  corLimite: paleta.limite,
                  limite: limite,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
 
class _HorizontalPainter extends CustomPainter {
  _HorizontalPainter({
    required this.pontos,
    required this.teto,
    required this.passo,
    required this.cor,
    required this.corLimite,
    this.limite,
  });
 
  final List<PontoSessao> pontos;
  final double teto;
  final double passo;
  final Color cor;
  final Color corLimite;
  final double? limite;
 
  @override
  void paint(Canvas canvas, Size size) {
    const esq = 132.0, dir = 12.0, topo = 34.0, linha = 42.0;
    final w = size.width - esq - dir;
    if (w <= 0) return;
    final h = pontos.length * linha;
    final grade = Paint()
      ..color = _corGrade
      ..strokeWidth = 1;
    final eixo = Paint()
      ..color = _corEixo
      ..strokeWidth = 1.4;
 
    // Grade vertical e valores do eixo X
    final n = (teto / passo).round();
    for (var i = 0; i <= n; i++) {
      final v = i * passo;
      final x = esq + w * v / teto;
      canvas.drawLine(Offset(x, topo), Offset(x, topo + h), grade);
      _texto(canvas, '${v.round()}', Offset(x, topo + h + 6));
    }
    canvas.drawLine(Offset(esq, topo), Offset(esq, topo + h), eixo);
    canvas.drawLine(Offset(esq, topo + h), Offset(esq + w, topo + h), eixo);
 
    // Título do eixo Y, como no gráfico de barras verticais.
    canvas.save();
    canvas.translate(10, topo + h / 2);
    canvas.rotate(-math.pi / 2);
    _texto(
      canvas,
      'Sessões de jogo',
      Offset.zero,
      ref: Alignment.center,
      estilo: const TextStyle(color: _corTexto, fontSize: 12),
    );
    canvas.restore();

    // Categorias no eixo vertical: uma sessão por barra.
    // A duração é lida na escala horizontal, como em um gráfico tradicional.
    // Barras
    for (var i = 0; i < pontos.length; i++) {
      final p = pontos[i];
      final yc = topo + linha * i + linha / 2;
      final largura = w * (p.minutos.clamp(0.0, teto)) / teto;
      _texto(
        canvas,
        p.data.isEmpty ? 'Sessão #${p.id}' : 'Sessão #${p.id}\n${p.data}',
        Offset(esq - 8, yc),
        ref: Alignment.centerRight,
        alinhar: TextAlign.right,
        larguraMax: esq - 12,
        estilo: const TextStyle(color: _corTexto, fontSize: 11, height: 1.15),
      );
      final retangulo = RRect.fromRectAndRadius(
        Rect.fromLTWH(esq, yc - 10, math.max(largura, 3), 20),
        const Radius.circular(4),
      );
      canvas.drawRRect(retangulo, Paint()..color = cor);
      canvas.drawRRect(
        retangulo,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white70
          ..strokeWidth = 1,
      );
      // Rótulo de dados: duração ao final de cada barra, como no segundo gráfico.
      final valor = '${p.minutos.round()}';
      final estiloValor = const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      );
      final dentro = largura >= 39 && (esq + largura + 34 > size.width);
      _texto(
        canvas,
        valor,
        Offset(esq + largura + (dentro ? -6 : 6), yc),
        ref: dentro ? Alignment.centerRight : Alignment.centerLeft,
        estilo: estiloValor,
        larguraMax: 40,
      );
    }
 
    // Linha do limite escolhido
    final lim = limite;
    if (lim != null && lim > 0) {
      final x = esq + w * lim.clamp(0.0, teto) / teto;
      _tracejado(
        canvas,
        Offset(x, topo - 4),
        Offset(x, topo + h),
        Paint()
          ..color = corLimite
          ..strokeWidth = 2,
      );
      _texto(
        canvas,
        'Seu limite: ${lim.round()} min',
        Offset(math.min(x, size.width - 60), topo - 6),
        ref: Alignment.bottomCenter,
        estilo: TextStyle(
          color: corLimite,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        fundo: _corFundoCartao,
      );
    }
 
    // Título do eixo X
    _texto(
      canvas,
      'Duração da sessão (minutos)',
      Offset(esq + w / 2, size.height - 4),
      ref: Alignment.bottomCenter,
    );
  }
 
  @override
  bool shouldRepaint(covariant _HorizontalPainter old) => true;
}
 
// ============================================================
// 2) BARRAS VERTICAIS / LINHA — duração por sessão ao longo do tempo
// ============================================================
 
class GraficoCartesianoSessoes extends StatelessWidget {
  const GraficoCartesianoSessoes({
    super.key,
    required this.pontos,
    required this.paleta,
    required this.periodo,
    required this.linhas,
    this.limite,
  });
 
  final List<PontoSessao> pontos;
  final PaletaGraficos paleta;
  final String periodo;
  final bool linhas;
  final double? limite;
 
  @override
  Widget build(BuildContext context) {
    if (pontos.isEmpty) {
      return Text('Nenhuma sessão encontrada em: $periodo.');
    }
    final maior = math.max(
      pontos.map((p) => p.minutos).reduce(math.max),
      limite ?? 0.0,
    );
    final escala = _escala(maior);
 
    return Semantics(
      label: _descricaoAcessivel(
        linhas ? 'Gráfico de linha' : 'Gráfico de barras',
        pontos,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            linhas
                ? 'Tempo total jogado por dia • $periodo. '
                  'Cada ponto representa a soma das sessões daquele dia.'
                : _fraseResumo(pontos, limite, periodo),
            style: const TextStyle(fontSize: 12, color: _corTexto),
          ),
          if (limite != null && limite! > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(width: 25, height: 3, color: paleta.limite),
                const SizedBox(width: 8),
                Flexible(child: Text('Linha tracejada: limite de ${limite!.round()} min',
                    style: const TextStyle(fontSize: 12, color: _corTexto))),
              ],
            ),
          ],
          const SizedBox(height: 12),
          ExcludeSemantics(
            child: SizedBox(
              width: double.infinity,
              height: 290,
              child: CustomPaint(
                painter: _CartesianoPainter(
                  valores: pontos.map((p) => p.minutos).toList(),
                  rotulos: pontos.map((p) => linhas && p.data.isNotEmpty ? p.data : '#${p.id}').toList(),
                  teto: escala[0],
                  passo: escala[1],
                  cor: paleta.serie1,
                  linhas: linhas,
                  corLimite: paleta.limite,
                  limite: limite,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
 
class _CartesianoPainter extends CustomPainter {
  _CartesianoPainter({
    required this.valores,
    required this.rotulos,
    required this.teto,
    required this.passo,
    required this.cor,
    required this.linhas,
    required this.corLimite,
    this.limite,
  });
 
  final List<double> valores;
  final List<String> rotulos;
  final double teto;
  final double passo;
  final Color cor;
  final bool linhas;
  final Color corLimite;
  final double? limite;
 
  @override
  void paint(Canvas canvas, Size size) {
    if (valores.isEmpty) return;
    const esq = 64.0, dir = 12.0, topo = 24.0, base = 78.0;
    final w = size.width - esq - dir;
    final h = size.height - topo - base;
    if (w <= 0 || h <= 0) return;
 
    final grade = Paint()
      ..color = _corGrade
      ..strokeWidth = 1;
    final eixo = Paint()
      ..color = _corEixo
      ..strokeWidth = 1.4;
 
    double yDe(double v) => topo + h * (1 - v.clamp(0.0, teto) / teto);
 
    // Grade e valores do eixo Y
    final n = (teto / passo).round();
    for (var i = 0; i <= n; i++) {
      final v = i * passo;
      final y = yDe(v);
      canvas.drawLine(Offset(esq, y), Offset(esq + w, y), grade);
      _texto(
        canvas,
        '${v.round()}',
        Offset(esq - 6, y),
        ref: Alignment.centerRight,
        alinhar: TextAlign.right,
      );
    }
    canvas.drawLine(Offset(esq, topo), Offset(esq, topo + h), eixo);
    canvas.drawLine(Offset(esq, topo + h), Offset(esq + w, topo + h), eixo);
 
    final faixa = w / valores.length;
    Offset ponto(int i) => Offset(esq + faixa * (i + 0.5), yDe(valores[i]));
 
    if (linhas) {
      final caminho = Path()..moveTo(ponto(0).dx, ponto(0).dy);
      for (var i = 1; i < valores.length; i++) {
        caminho.lineTo(ponto(i).dx, ponto(i).dy);
      }
      canvas.drawPath(
        caminho,
        Paint()
          ..color = cor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (var i = 0; i < valores.length; i++) {
        canvas.drawCircle(ponto(i), 5.5, Paint()..color = cor);
        canvas.drawCircle(ponto(i), 2.5, Paint()..color = _corFundoCartao);
      }
    } else {
      final larguraBarra = math.min(40.0, faixa * 0.68);
      for (var i = 0; i < valores.length; i++) {
        final p = ponto(i);
        final barra = RRect.fromRectAndCorners(
          Rect.fromLTRB(
            p.dx - larguraBarra / 2,
            p.dy,
            p.dx + larguraBarra / 2,
            topo + h,
          ),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(barra, Paint()..color = cor);
        canvas.drawRRect(
          barra,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.white70
            ..strokeWidth = 1,
        );
      }
    }
 
    // Valores acima de cada barra/ponto
    for (var i = 0; i < valores.length; i++) {
      final p = ponto(i);
      _texto(
        canvas,
        '${valores[i].round()}',
        Offset(p.dx, p.dy - (linhas ? 9 : 4)),
        ref: Alignment.bottomCenter,
        estilo: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
    }
 
    // Linha do limite escolhido
    final lim = limite;
    if (lim != null && lim > 0) {
      final y = yDe(lim);
      _tracejado(
        canvas,
        Offset(esq, y),
        Offset(esq + w, y),
        Paint()
          ..color = corLimite
          ..strokeWidth = 2,
      );
    }
 
    // Rótulos do eixo X (data e número da sessão)
    for (var i = 0; i < rotulos.length; i++) {
      _texto(
        canvas,
        rotulos[i],
        Offset(esq + faixa * (i + 0.5), topo + h + 7 + (linhas && i.isOdd ? 18 : 0)),
        larguraMax: math.max(42, faixa - 2),
      );
    }
 
    // Títulos dos eixos
    _texto(
      canvas,
      linhas ? 'Dia (dia/mês)' : 'Número da sessão',
      Offset(esq + w / 2, size.height - 2),
      ref: Alignment.bottomCenter,
    );
    canvas.save();
    canvas.translate(12, topo + h / 2);
    canvas.rotate(-math.pi / 2);
    _texto(canvas, linhas ? 'Tempo total (min)' : 'Duração (minutos)', Offset.zero, ref: Alignment.center);
    canvas.restore();
  }
 
  @override
  bool shouldRepaint(covariant _CartesianoPainter old) => true;
}
 
// ============================================================
// 3) ROSCA — sessões com e sem pausas (cor + textura + rótulo)
// ============================================================
 
class GraficoRoscaPausas extends StatelessWidget {
  const GraficoRoscaPausas({
    super.key,
    required this.comPausas,
    required this.semPausas,
    required this.paleta,
    required this.periodo,
  });
 
  final int comPausas;
  final int semPausas;
  final PaletaGraficos paleta;
  final String periodo;
 
  String _pct(int qtd, int total) =>
      (100 * qtd / total).toStringAsFixed(1).replaceAll('.', ',');
 
  @override
  Widget build(BuildContext context) {
    final total = comPausas + semPausas;
    if (total == 0) {
      return Text('Nenhuma sessão encontrada em: $periodo.');
    }
 
    Widget legenda(Color cor, bool hachurada, String titulo, int qtd) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              child: CustomPaint(
                size: const Size(18, 18),
                painter: _AmostraPainter(cor, hachurada),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$qtd de $total sessões • ${_pct(qtd, total)}%',
                    style: const TextStyle(fontSize: 12, color: _corTexto),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
 
    return Semantics(
      label:
          'Gráfico de rosca. Com pausas: $comPausas de $total sessões '
          '(${_pct(comPausas, total)}%). '
          'Sem pausas: $semPausas de $total sessões '
          '(${_pct(semPausas, total)}%).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proporção das $total sessões que tiveram ao menos uma pausa • '
            '$periodo.',
            style: const TextStyle(fontSize: 12, color: _corTexto),
          ),
          const SizedBox(height: 16),
          ExcludeSemantics(
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CustomPaint(
                    painter: _RoscaPainter(
                      comPausas: comPausas.toDouble(),
                      semPausas: semPausas.toDouble(),
                      cor1: paleta.serie1,
                      cor2: paleta.serie2,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      legenda(paleta.serie1, false, 'Com pausas', comPausas),
                      legenda(paleta.serie2, true, 'Sem pausas', semPausas),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Cada categoria tem cor e textura próprias, além do nome e do '
            'percentual.',
            style: TextStyle(fontSize: 12, color: _corTexto),
          ),
        ],
      ),
    );
  }
}
 
class _RoscaPainter extends CustomPainter {
  _RoscaPainter({
    required this.comPausas,
    required this.semPausas,
    required this.cor1,
    required this.cor2,
  });
 
  final double comPausas;
  final double semPausas;
  final Color cor1;
  final Color cor2;
 
  Path _fatia(Offset centro, double rExt, double rInt, double ini, double var_) {
    final v = math.min(var_, 2 * math.pi - 0.0001);
    return Path()
      ..arcTo(Rect.fromCircle(center: centro, radius: rExt), ini, v, false)
      ..arcTo(Rect.fromCircle(center: centro, radius: rInt), ini + v, -v, false)
      ..close();
  }
 
  @override
  void paint(Canvas canvas, Size size) {
    final total = comPausas + semPausas;
    if (total <= 0) return;
    final centro = Offset(size.width / 2, size.height / 2);
    final rExt = math.min(size.width, size.height) / 2 - 3;
    final rInt = rExt * 0.58;
    const inicio = -math.pi / 2;
    final arco1 = 2 * math.pi * comPausas / total;
    final arco2 = 2 * math.pi - arco1;
 
    void desenhar(double ini, double varredura, Color cor, bool hachurada) {
      if (varredura <= 0) return;
      final caminho = _fatia(centro, rExt, rInt, ini, varredura);
      canvas.drawPath(caminho, Paint()..color = cor);
      if (hachurada) {
        canvas.save();
        canvas.clipPath(caminho);
        _hachura(
          canvas,
          Rect.fromCircle(center: centro, radius: rExt),
          const Color(0x99000000),
        );
        canvas.restore();
      }
      canvas.drawPath(
        caminho,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = _corFundoCartao
          ..strokeWidth = 2.5,
      );
    }
 
    desenhar(inicio, arco1, cor1, false);
    desenhar(inicio + arco1, arco2, cor2, true);
 
    _texto(
      canvas,
      '${total.round()}',
      centro,
      ref: Alignment.bottomCenter,
      estilo: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    );
    _texto(canvas, 'sessões', centro, ref: Alignment.topCenter);
  }
 
  @override
  bool shouldRepaint(covariant _RoscaPainter old) =>
      old.comPausas != comPausas ||
      old.semPausas != semPausas ||
      old.cor1 != cor1 ||
      old.cor2 != cor2;
}
 
class _AmostraPainter extends CustomPainter {
  _AmostraPainter(this.cor, this.hachurada);
 
  final Color cor;
  final bool hachurada;
 
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(3),
    );
    canvas.drawRRect(r, Paint()..color = cor);
    if (hachurada) {
      canvas.save();
      canvas.clipRRect(r);
      _hachura(canvas, Offset.zero & size, const Color(0x99000000));
      canvas.restore();
    }
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white70
        ..strokeWidth = 1,
    );
  }
 
  @override
  bool shouldRepaint(covariant _AmostraPainter old) =>
      old.cor != cor || old.hachurada != hachurada;
}
 