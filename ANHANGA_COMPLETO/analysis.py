
import math
from statistics import mean, median, pstdev
from typing import Any


# ============================================================
# 1. ESTATISTICA DESCRITIVA
# ============================================================

def calcular_media(valores: list[float]) -> float | None:
    if not valores:
        return None
    return round(mean(valores), 2)


def calcular_mediana(valores: list[float]) -> float | None:
    if not valores:
        return None
    return round(median(valores), 2)


def calcular_desvio_padrao(
    valores: list[float],
) -> float | None:
    if not valores:
        return None
    return round(pstdev(valores), 2)


def calcular_z_score(
    valor: float,
    historico: list[float],
) -> float | None:
    if len(historico) < 2:
        return None

    desvio = pstdev(historico)

    if desvio == 0:
        return None

    return round((valor - mean(historico)) / desvio, 2)


# ============================================================
# 2. VALIDACAO DOS VALORES
# ============================================================

def validar_numero(
    nome: str,
    valor: float | None,
    minimo: float | None = None,
    maximo: float | None = None,
) -> float | None:
    """Valida um número opcional sem aceitar NaN ou infinito."""

    if valor is None:
        return None

    if isinstance(valor, bool):
        raise ValueError(f"{nome} precisa ser um número válido.")

    try:
        numero = float(valor)
    except (TypeError, ValueError):
        raise ValueError(
            f"{nome} precisa ser um número válido."
        ) from None

    if not math.isfinite(numero):
        raise ValueError(
            f"{nome} precisa ser um número finito."
        )

    if minimo is not None and numero < minimo:
        raise ValueError(
            f"{nome} não pode ser menor que {minimo}."
        )

    if maximo is not None and numero > maximo:
        raise ValueError(
            f"{nome} não pode ser maior que {maximo}."
        )

    return numero


# ============================================================
# 3. ANALISE PRINCIPAL DO ANHANGA
# ============================================================

def analisar_sessao(
    historico: list[float] | None = None,
    duracao_atual: float = 0,
    quantidade_pausas: int = 0,
    temperatura: float | None = None,
    umidade: float | None = None,
    luminosidade: float | None = None,
    ruido_db: float | None = None,
    limite_minutos: float | None = None,
    historico_minutos: list[float] | None = None,
    temperatura_min: float = 18,
    temperatura_max: float = 28,
    umidade_min: float = 30,
    umidade_max: float = 70,
    luminosidade_min: float = 100,
    luminosidade_max: float = 500,
    ruido_max: float = 70,
    preferencia_temperatura: float | None = None,
    preferencia_luminosidade: float | None = None,
    preferencia_ruido_db: float | None = None,
    tolerancia_temperatura: float = 2,
    tolerancia_luminosidade: float = 50,
) -> dict[str, Any]:
    """
    Analisa a duração, o histórico e o contexto ambiental.

    Os limites ambientais são referências iniciais do protótipo.
    Quando fornecidas, as preferências individuais de temperatura,
    luminosidade e ruído têm prioridade sobre as faixas de referência.

    Temperatura e luminosidade são comparadas com tolerâncias
    configuráveis. Ruído é comparado com o máximo pessoal informado.

    A análise é estatística e heurística; não é um modelo de
    aprendizado de máquina treinado.
    """

    # --------------------------------------------------------
    # Validacao dos argumentos
    # --------------------------------------------------------

    if historico is not None and historico_minutos is not None:
        raise ValueError(
            "Informe historico ou historico_minutos, não ambos."
        )

    dados_historicos = (
        historico
        if historico is not None
        else historico_minutos
    )

    duracao = validar_numero(
        "Duração", duracao_atual, minimo=0
    )

    pausas_numero = validar_numero(
        "Quantidade de pausas", quantidade_pausas, minimo=0
    )

    if not pausas_numero.is_integer():
        raise ValueError(
            "A quantidade de pausas deve ser um número inteiro."
        )

    pausas = int(pausas_numero)

    limite_minutos = validar_numero(
        "Limite de minutos", limite_minutos, minimo=0
    )

    temperatura = validar_numero(
        "Temperatura", temperatura, minimo=-50, maximo=80
    )

    umidade = validar_numero(
        "Umidade", umidade, minimo=0, maximo=100
    )

    luminosidade = validar_numero(
        "Luminosidade", luminosidade, minimo=0
    )

    ruido_db = validar_numero(
        "Ruído", ruido_db, minimo=0
    )

    preferencia_temperatura = validar_numero(
        "Preferência de temperatura",
        preferencia_temperatura,
        minimo=-50,
        maximo=80,
    )
    preferencia_luminosidade = validar_numero(
        "Preferência de luminosidade",
        preferencia_luminosidade,
        minimo=0,
    )
    preferencia_ruido_db = validar_numero(
        "Preferência de ruído máximo",
        preferencia_ruido_db,
        minimo=0,
    )
    tolerancia_temperatura = validar_numero(
        "Tolerância de temperatura",
        tolerancia_temperatura,
        minimo=0,
    )
    tolerancia_luminosidade = validar_numero(
        "Tolerância de luminosidade",
        tolerancia_luminosidade,
        minimo=0,
    )

    limites = [
        temperatura_min,
        temperatura_max,
        umidade_min,
        umidade_max,
        luminosidade_min,
        luminosidade_max,
        ruido_max,
    ]

    for nome, valor in zip(
        [
            "temperatura_min",
            "temperatura_max",
            "umidade_min",
            "umidade_max",
            "luminosidade_min",
            "luminosidade_max",
            "ruido_max",
        ],
        limites,
    ):
        validar_numero(nome, valor)

    if temperatura_min >= temperatura_max:
        raise ValueError(
            "temperatura_min deve ser menor que temperatura_max."
        )

    if umidade_min >= umidade_max:
        raise ValueError(
            "umidade_min deve ser menor que umidade_max."
        )

    if luminosidade_min >= luminosidade_max:
        raise ValueError(
            "luminosidade_min deve ser menor que luminosidade_max."
        )

    historico_limpo = []

    for valor in dados_historicos or []:
        numero = validar_numero(
            "Duração histórica", valor, minimo=0
        )
        historico_limpo.append(numero)

    # --------------------------------------------------------
    # Estatistica historica
    # --------------------------------------------------------

    media_historico = calcular_media(historico_limpo)
    mediana_historico = calcular_mediana(historico_limpo)
    desvio_historico = calcular_desvio_padrao(historico_limpo)

    z_score = calcular_z_score(duracao, historico_limpo)

    # Estimativa pela média histórica, não por ML treinado.
    duracao_prevista = media_historico

    # --------------------------------------------------------
    # Classificacao estatistica
    # --------------------------------------------------------

    if z_score is None:
        classificacao = "historico_insuficiente"
    elif z_score >= 2:
        classificacao = "muito_acima_do_padrao"
    elif z_score <= -2:
        classificacao = "muito_abaixo_do_padrao"
    else:
        classificacao = "dentro_do_padrao"

    if z_score is None:
        score_anomalia = 0.0
    else:
        score_anomalia = round(
            min(100.0, abs(z_score) * 25.0), 2
        )

    # --------------------------------------------------------
    # Analise contextual e ambiental
    # --------------------------------------------------------

    score_contexto = 0.0
    fatores_contextuais = []

    # Duração e pausas
    if duracao >= 60 and pausas == 0:
        score_contexto += 15
        fatores_contextuais.append(
            "Sessão de pelo menos 60 minutos sem pausas."
        )

    # Temperatura: preferência individual, quando informada;
    # caso contrário, utiliza a faixa geral de referência.
    if temperatura is not None:
        if preferencia_temperatura is not None:
            temperatura_fora_preferencia = (
                abs(temperatura - preferencia_temperatura)
                > tolerancia_temperatura
            )
            if temperatura_fora_preferencia:
                score_contexto += 15
                fatores_contextuais.append(
                    "Temperatura diferente da preferência pessoal "
                    f"({preferencia_temperatura:g} °C, tolerância "
                    f"de ±{tolerancia_temperatura:g} °C)."
                )
        elif not temperatura_min <= temperatura <= temperatura_max:
            score_contexto += 15
            fatores_contextuais.append(
                "Temperatura fora da faixa de referência configurada."
            )

    # Umidade
    if umidade is not None:
        if not umidade_min <= umidade <= umidade_max:
            score_contexto += 10
            fatores_contextuais.append(
                "Umidade fora da faixa configurada."
            )

    # Luminosidade: preferência individual, quando informada;
    # caso contrário, utiliza a faixa geral de referência.
    if luminosidade is not None:
        if preferencia_luminosidade is not None:
            luminosidade_fora_preferencia = (
                abs(luminosidade - preferencia_luminosidade)
                > tolerancia_luminosidade
            )
            if luminosidade_fora_preferencia:
                score_contexto += 10
                fatores_contextuais.append(
                    "Luminosidade diferente da preferência pessoal "
                    f"({preferencia_luminosidade:g} lux, tolerância "
                    f"de ±{tolerancia_luminosidade:g} lux)."
                )
        elif not luminosidade_min <= luminosidade <= luminosidade_max:
            score_contexto += 10
            fatores_contextuais.append(
                "Luminosidade fora da faixa de referência configurada."
            )

    # Ruído: preferência individual tem prioridade sobre o padrão geral.
    limite_ruido_aplicado = (
        preferencia_ruido_db
        if preferencia_ruido_db is not None
        else ruido_max
    )
    if ruido_db is not None and ruido_db > limite_ruido_aplicado:
        score_contexto += 10
        fatores_contextuais.append(
            "Ruído ambiental acima do limite "
            f"{'pessoal' if preferencia_ruido_db is not None else 'de referência'} "
            f"configurado ({limite_ruido_aplicado:g} dB)."
        )

    score_contexto = round(min(100.0, score_contexto), 2)

    # --------------------------------------------------------
    # Probabilidade heuristica de sessao prolongada
    # --------------------------------------------------------

    if limite_minutos is not None:
        if limite_minutos == 0:
            probabilidade_prolongada = (
                100.0 if duracao > 0 else 0.0
            )
        elif duracao > limite_minutos:
            excesso = (
                (duracao - limite_minutos) / limite_minutos
            )
            probabilidade_prolongada = round(
                min(100.0, 50.0 + excesso * 50.0), 2
            )
        else:
            proporcao = duracao / limite_minutos
            probabilidade_prolongada = round(
                min(49.0, max(0.0, proporcao * 49.0)), 2
            )

    elif duracao_prevista is not None and duracao_prevista > 0:
        proporcao = duracao / duracao_prevista
        probabilidade_prolongada = round(
            min(100.0, max(0.0, proporcao * 50.0)), 2
        )
    else:
        probabilidade_prolongada = 0.0

    # --------------------------------------------------------
    # Recomendacoes
    # --------------------------------------------------------

    recomendacoes = []

    if limite_minutos is not None and duracao > limite_minutos:
        recomendacoes.append(
            "A sessão ultrapassou o limite de tempo escolhido."
        )

    if duracao >= 90 and pausas == 0:
        recomendacoes.append(
            "Considere fazer uma pausa."
        )

    if z_score is not None and abs(z_score) >= 2:
        recomendacoes.append(
            "A duração está distante do padrão histórico."
        )

    if score_contexto > 0:
        recomendacoes.append(
            "Considere revisar as condições do ambiente."
        )

    if not recomendacoes:
        recomendacoes.append(
            "Continue acompanhando suas sessões e preferências."
        )

    return {
        "classificacao": classificacao,
        "score_anomalia": score_anomalia,
        "score_contexto": score_contexto,
        "duracao_prevista": duracao_prevista,
        "probabilidade_prolongada": probabilidade_prolongada,
        "recomendacao": recomendacoes[0],

        "duracao_atual_minutos": round(duracao, 2),
        "quantidade_pausas": pausas,
        "quantidade_sessoes_historico": len(historico_limpo),
        "media_minutos": media_historico,
        "mediana_minutos": mediana_historico,
        "desvio_padrao_minutos": desvio_historico,
        "z_score": z_score,
        "limite_escolhido_minutos": limite_minutos,

        "recomendacoes": recomendacoes,
        "fatores_contextuais": fatores_contextuais,
        "tipo_analise": "estatistica_heuristica",
        "dados_ambientais": {
            "temperatura": temperatura,
            "umidade": umidade,
            "luminosidade": luminosidade,
            "ruido_db": ruido_db,
        },
        "preferencias_ambientais_aplicadas": {
            "temperatura_preferida": preferencia_temperatura,
            "tolerancia_temperatura": tolerancia_temperatura,
            "luminosidade_preferida": preferencia_luminosidade,
            "tolerancia_luminosidade": tolerancia_luminosidade,
            "ruido_maximo_pessoal_db": preferencia_ruido_db,
        },
    }


# ============================================================
# 4. DERIVADA E DESCIDA DO GRADIENTE
# ============================================================

def demonstrar_derivada(
    x: float = 75,
    alvo: float = 70,
    taxa_aprendizado: float = 0.1,
) -> dict[str, float]:
    """
    Demonstra a função f(x) = (x - alvo)^2.

    Derivada: f'(x) = 2 * (x - alvo)
    Atualização: x_novo = x - taxa * derivada
    """

    x = validar_numero("x", x)
    alvo = validar_numero("alvo", alvo)
    taxa_aprendizado = validar_numero(
        "Taxa de aprendizado", taxa_aprendizado, minimo=0
    )

    derivada = 2 * (x - alvo)
    proximo_x = x - taxa_aprendizado * derivada

    return {
        "x_inicial": round(x, 4),
        "alvo": round(alvo, 4),
        "derivada": round(derivada, 4),
        "taxa_aprendizado": round(taxa_aprendizado, 4),
        "proximo_x": round(proximo_x, 4),
    }


# ============================================================
# 5. ANALISE DE MATRIZ
# ============================================================

def analisar_matriz(
    matriz: list[list[float]],
) -> dict[str, Any]:
    """Calcula a média de cada coluna de uma matriz numérica."""

    if not matriz:
        raise ValueError("A matriz não pode estar vazia.")

    quantidade_colunas = len(matriz[0])

    if quantidade_colunas == 0:
        raise ValueError("A matriz precisa ter colunas.")

    matriz_validada = []

    for linha in matriz:
        if len(linha) != quantidade_colunas:
            raise ValueError(
                "Todas as linhas devem ter o mesmo número de colunas."
            )

        matriz_validada.append([
            validar_numero("Valor da matriz", valor)
            for valor in linha
        ])

    medias_colunas = [
        round(
            mean(
                linha[coluna]
                for linha in matriz_validada
            ),
            2,
        )
        for coluna in range(quantidade_colunas)
    ]

    return {
        "quantidade_linhas": len(matriz_validada),
        "quantidade_colunas": quantidade_colunas,
        "matriz": matriz_validada,
        "medias_por_coluna": medias_colunas,
    }


# ============================================================
# 6. DEMONSTRACAO MATEMATICA
# ============================================================

def demonstracao_matematica() -> dict[str, Any]:
    """Exemplos fictícios para demonstrar os cálculos."""

    duracoes = [60, 70, 80, 90, 200]

    matriz_sessoes = [
        [60, 2, 24],
        [80, 3, 25],
        [160, 1, 26],
    ]

    return {
        "demonstracao": True,
        "aviso": (
            "Valores fictícios usados apenas para demonstração."
        ),
        "estatistica": {
            "duracoes_minutos": duracoes,
            "media": calcular_media(duracoes),
            "mediana": calcular_mediana(duracoes),
            "desvio_padrao": calcular_desvio_padrao(duracoes),
            "z_scores": [
                calcular_z_score(valor, duracoes)
                for valor in duracoes
            ],
        },
        "derivada": demonstrar_derivada(),
        "matriz_sessoes": analisar_matriz(matriz_sessoes),
    }