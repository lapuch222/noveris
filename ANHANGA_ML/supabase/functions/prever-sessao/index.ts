

const PESOS = [
  -3.2329763634797875,
  2.0517283481331825,
  3.104784955999392,
  -0.8402353532461814,
];

const LIMIAR = 0.5;

function sigmoid(valor: number): number {
  return 1 / (1 + Math.exp(-valor));
}

function prever(
  duracaoAtual: number,
  limiteMinutos: number,
  mediaHistorica: number,
  pausas: number,
) {
  const limiteSeguro = Math.max(limiteMinutos, 1);

  const caracteristicas = [
    1,
    duracaoAtual / limiteSeguro,
    mediaHistorica / limiteSeguro,
    pausas / 5,
  ];

  const soma = caracteristicas.reduce(
    (total, valor, indice) => total + valor * PESOS[indice],
    0,
  );

  const pontuacao = sigmoid(soma);

  return {
    pontuacao_modelo: Number((pontuacao * 100).toFixed(2)),
    classificacao_modelo: pontuacao >= LIMIAR
      ? "risco_elevado"
      : "risco_abaixo_do_limiar",
    limite_atingido: duracaoAtual >= limiteSeguro,
    origem_modelo: "dados_sinteticos",
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, apikey, content-type",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
      },
    });
  }

  if (req.method !== "POST") {
    return Response.json(
      { erro: "Utilize o método POST." },
      { status: 405 },
    );
  }

  try {
    const dados = await req.json();

    const duracaoAtual = dados.duracao_atual;
    const limiteMinutos = dados.limite_minutos;
    const mediaHistorica = dados.media_historica;
    const pausas = dados.pausas;

    const valores = [
      duracaoAtual,
      limiteMinutos,
      mediaHistorica,
      pausas,
    ];

    if (
      !valores.every(
        (valor) =>
          typeof valor === "number" && Number.isFinite(valor),
      ) ||
      duracaoAtual < 0 ||
      limiteMinutos <= 0 ||
      mediaHistorica < 0 ||
      pausas < 0
    ) {
      return Response.json(
        {
          erro:
            "Informe duração, limite, média histórica e pausas com valores numéricos válidos.",
        },
        { status: 400 },
      );
    }

    return Response.json({
      projeto: "ANHANGÁ",
      algoritmo: "regressao_logistica",
      resultado: prever(
        duracaoAtual,
        limiteMinutos,
        mediaHistorica,
        pausas,
      ),
      aviso:
        "Modelo experimental treinado com dados sintéticos. A pontuação não é uma probabilidade validada de comportamento real.",
    });
  } catch {
    return Response.json(
      { erro: "Não foi possível processar o JSON enviado." },
      { status: 400 },
    );
  }
});
