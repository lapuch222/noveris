
type Modelo = {
  limiar: number;
  pesos: number[];
  origem_dados: string;
};

const modelo: Modelo = JSON.parse(
  await Deno.readTextFile("./model.json"),
);

function prever(
  duracao: number,
  limite: number,
  mediaHistorica: number,
  pausas: number,
) {
  const valores = [duracao, limite, mediaHistorica, pausas];

  if (!valores.every(Number.isFinite)) {
    throw new Error("Todos os valores devem ser números válidos.");
  }

  if (duracao < 0 || limite <= 0 || mediaHistorica < 0 || pausas < 0) {
    throw new Error("Duração, média e pausas não podem ser negativas; o limite deve ser maior que zero.");
  }

  if (!Number.isInteger(pausas)) {
    throw new Error("A quantidade de pausas deve ser um número inteiro.");
  }

  const x = [
    1,
    duracao / limite,
    mediaHistorica / limite,
    pausas / 5,
  ];

  const soma = x.reduce(
    (total, valor, i) => total + valor * modelo.pesos[i],
    0,
  );

  const probabilidade = 1 / (
    1 + Math.exp(-Math.max(-30, Math.min(30, soma)))
  );

  return {
    probabilidade: Number((probabilidade * 100).toFixed(2)),
    classificacao: probabilidade >= modelo.limiar
      ? "RISCO ELEVADO"
      : "ABAIXO DO LIMIAR DO MODELO",
    limiteAtingido: duracao >= limite,
  };
}

console.log("=== ANHANGÁ | TESTES DE PREVISÃO ===");
console.log("Modelo:", modelo.origem_dados);

const casos = [
  {
    nome: "Sessão abaixo do limite",
    duracao: 20,
    limite: 60,
    media: 45,
    pausas: 2,
  },
  {
    nome: "Sessão no limite",
    duracao: 60,
    limite: 60,
    media: 45,
    pausas: 2,
  },
  {
    nome: "Sessão acima do limite",
    duracao: 90,
    limite: 60,
    media: 75,
    pausas: 2,
  },
];

for (const caso of casos) {
  const resultado = prever(
    caso.duracao,
    caso.limite,
    caso.media,
    caso.pausas,
  );

  console.log(`\n${caso.nome}`);
  console.log(`Duração: ${caso.duracao} min`);
  console.log(`Limite: ${caso.limite} min`);
  console.log(`Probabilidade do modelo: ${resultado.probabilidade}%`);
  console.log(`Classificação: ${resultado.classificacao}`);
  console.log(`Limite já atingido: ${resultado.limiteAtingido ? "Sim" : "Não"}`);
}
