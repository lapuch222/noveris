

type Exemplo = {
  duracaoAtual: number;
  limite: number;
  mediaHistorica: number;
  pausas: number;
  alvo: number;
};

let estado = 20261027;

function aleatorio(): number {
  estado = (estado * 1664525 + 1013904223) >>> 0;
  return estado / 4294967296;
}

function sigmoid(x: number): number {
  return 1 / (1 + Math.exp(-Math.max(-30, Math.min(30, x))));
}

function gerarDados(quantidade: number): Exemplo[] {
  const dados: Exemplo[] = [];

  for (let i = 0; i < quantidade; i++) {
    const limite = 30 + aleatorio() * 150;
    const mediaHistorica = 20 + aleatorio() * 180;
    const duracaoAtual = aleatorio() * limite * 1.3;
    const pausas = Math.floor(aleatorio() * 6);
    const duracaoFinal = Math.max(
      duracaoAtual,
      mediaHistorica * (0.65 + aleatorio() * 0.85),
    );

    dados.push({
      duracaoAtual,
      limite,
      mediaHistorica,
      pausas,
      alvo: duracaoFinal > limite ? 1 : 0,
    });
  }

  return dados;
}

function recursos(e: Exemplo): number[] {
  return [
    1,
    e.duracaoAtual / e.limite,
    e.mediaHistorica / e.limite,
    e.pausas / 5,
  ];
}

const dados = gerarDados(2000);

for (let i = dados.length - 1; i > 0; i--) {
  const j = Math.floor(aleatorio() * (i + 1));
  [dados[i], dados[j]] = [dados[j], dados[i]];
}

const corte = Math.floor(dados.length * 0.8);
const treino = dados.slice(0, corte);
const teste = dados.slice(corte);
const pesos = [0, 0, 0, 0];

for (let epoca = 0; epoca < 3000; epoca++) {
  const gradientes = [0, 0, 0, 0];

  for (const e of treino) {
    const x = recursos(e);
    const p = sigmoid(x.reduce((s, v, i) => s + v * pesos[i], 0));

    for (let i = 0; i < pesos.length; i++) {
      gradientes[i] += (p - e.alvo) * x[i];
    }
  }

  for (let i = 0; i < pesos.length; i++) {
    pesos[i] -= 0.05 * gradientes[i] / treino.length;
  }
}

let vp = 0, vn = 0, fp = 0, fn = 0;

for (const e of teste) {
  const x = recursos(e);
  const p = sigmoid(x.reduce((s, v, i) => s + v * pesos[i], 0));
  const previsto = p >= 0.5 ? 1 : 0;

  if (previsto === 1 && e.alvo === 1) vp++;
  else if (previsto === 0 && e.alvo === 0) vn++;
  else if (previsto === 1) fp++;
  else fn++;
}

const acuracia = (vp + vn) / teste.length;
const precisao = vp / Math.max(1, vp + fp);
const recall = vp / Math.max(1, vp + fn);

console.log("=== ANHANGÁ | MACHINE LEARNING ===");
console.log(`Treino: ${treino.length} exemplos`);
console.log(`Teste: ${teste.length} exemplos`);
console.log(`Acurácia: ${(acuracia * 100).toFixed(2)}%`);
console.log(`Precisão: ${(precisao * 100).toFixed(2)}%`);
console.log(`Recall: ${(recall * 100).toFixed(2)}%`);
console.log("Matriz de confusão:", { vp, vn, fp, fn });

const modelo = {
  projeto: "ANHANGÁ",
  algoritmo: "regressao_logistica",
  origem_dados: "sinteticos",
  limiar: 0.5,
  caracteristicas: [
    "intercepto",
    "duracao_atual_dividida_pelo_limite",
    "media_historica_dividida_pelo_limite",
    "pausas_divididas_por_5",
  ],
  pesos,
};

await Deno.writeTextFile("model.json", JSON.stringify(modelo, null, 2));
console.log("Modelo salvo em model.json");

