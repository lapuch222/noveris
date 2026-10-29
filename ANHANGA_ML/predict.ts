
type Modelo = {
  projeto: string;
  algoritmo: string;
  origem_dados: string;
  limiar: number;
  caracteristicas: string[];
  pesos: number[];
};

const texto = await Deno.readTextFile("./model.json");
const modelo: Modelo = JSON.parse(texto);

function sigmoid(valor: number): number {
  return 1 / (1 + Math.exp(-Math.max(-30, Math.min(30, valor))));
}

function preverRisco(
  duracaoAtual: number,
  limiteMinutos: number,
  mediaHistorica: number,
  pausas: number,
) {
  if (
    !Number.isFinite(duracaoAtual) ||
    !Number.isFinite(limiteMinutos) ||
    !Number.isFinite(mediaHistorica) ||
    !Number.isFinite(pausas) ||
    duracaoAtual < 0 ||
    limiteMinutos <= 0 ||
    mediaHistorica < 0 ||
    pausas < 0
  ) {
    throw new Error("Os valores informados são inválidos.");
  }

  const x = [
    1,
    duracaoAtual / limiteMinutos,
    mediaHistorica / limiteMinutos,
    pausas / 5,
  ];

  const soma = x.reduce(
    (total, valor, i) => total + valor * modelo.pesos[i],
    0,
  );

  const probabilidade = sigmoid(soma);
  const risco = probabilidade >= modelo.limiar;

  return {
    probabilidade: Number((probabilidade * 100).toFixed(2)),
    classificacao: risco ? "RISCO ELEVADO" : "RISCO ABAIXO DO LIMIAR",
  };
}

// Exemplo demonstrativo: sessão de 90 min, limite de 60 min.
const resultado = preverRisco(90, 60, 75, 2);

console.log("=== ANHANGÁ | TESTE DE PREVISÃO ===");
console.log("Origem do modelo:", modelo.origem_dados);
console.log("Duração atual: 90 minutos");
console.log("Limite escolhido: 60 minutos");
console.log("Média histórica: 75 minutos");
console.log("Pausas: 2");
console.log("Probabilidade calculada:", `${resultado.probabilidade}%`);
console.log("Classificação:", resultado.classificacao);
