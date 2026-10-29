import logging

from fastapi import FastAPI, HTTPException

from schemas import (
    UsuarioCreate,
    SessaoCreate,
    AnaliseRequest,
    PreferenciasUsuarioUpdate,
)
from analysis import analisar_sessao
from database import (
    obter_preferencias_usuario,
    atualizar_preferencias_usuario,
    testar_conexao,
    criar_usuario as salvar_usuario,
    registrar_sessao as salvar_sessao,
    obter_sessao_e_historico,
    salvar_resultado_analise,
    obter_conexao,
)


app = FastAPI(
    title="ANHANGÁ API",
    version="0.4.0",
    description=(
        "API do ANHANGÁ para registro de sessões, "
        "análise comportamental e consulta de indicadores."
    ),
)

logger = logging.getLogger(__name__)


# =========================================================
# 1. ROTA INICIAL
# =========================================================

@app.get("/")
def inicio():
    return {
        "projeto": "ANHANGÁ",
        "empresa": "NOVERIS",
        "status": "online",
        "versao": app.version,
    }


# =========================================================
# 2. VERIFICAR API
# =========================================================

@app.get("/health")
def health():
    return {"status": "ok"}


# =========================================================
# 3. VERIFICAR CONEXÃO COM SUPABASE
# =========================================================

@app.get("/health/database")
def health_database():
    try:
        return {
            "status": "ok",
            "database": testar_conexao(),
        }

    except Exception as erro:
        raise HTTPException(
            status_code=503,
            detail="Falha na conexão PostgreSQL/Supabase.",
        ) from erro


# =========================================================
# 4. CADASTRAR USUÁRIO
# =========================================================

@app.post("/usuarios", status_code=201)
def criar_usuario(usuario: UsuarioCreate):
    try:
        return salvar_usuario(
            nome=usuario.nome,
            perfil=usuario.perfil,
        )

    except Exception as erro:
        raise HTTPException(
            status_code=500,
            detail="Não foi possível cadastrar o usuário.",
        ) from erro



# =========================================================
# 5. REGISTRAR SESSÃO
# =========================================================

@app.post("/sessoes", status_code=201)
def registrar_sessao(sessao: SessaoCreate):
    try:
        resultado = salvar_sessao(
            id_usuario=sessao.id_usuario,
            inicio=sessao.inicio,
            fim=sessao.fim,
            duracao_minutos=sessao.duracao_minutos,
            quantidade_pausas=sessao.quantidade_pausas,
            plataforma=sessao.plataforma,
            id_dispositivo=sessao.id_dispositivo,

            # Dados ambientais
            temperatura=sessao.temperatura,
            umidade=sessao.umidade,
            luminosidade=sessao.luminosidade,
            ruido_db=sessao.ruido_db,
        )

        return resultado

    except ValueError as erro:
        raise HTTPException(
            status_code=400,
            detail=str(erro),
        ) from erro

    except Exception as erro:
        logger.exception(
            "Erro ao registrar sessão do ANHANGÁ."
        )
        raise HTTPException(
            status_code=500,
            detail="Não foi possível registrar a sessão.",
        ) from erro


# =========================================================
# 6. ANÁLISE COM HISTÓRICO ENVIADO NA REQUISIÇÃO
# =========================================================

@app.post("/analysis")
def analisar(request: AnaliseRequest):
    try:
        return analisar_sessao(
            historico=request.historico_minutos,
            duracao_atual=request.duracao_atual,
            quantidade_pausas=request.quantidade_pausas,
            temperatura=request.temperatura,
            umidade=request.umidade,
            luminosidade=request.luminosidade,
            ruido_db=request.ruido_db,
        )

    except ValueError as erro:
        raise HTTPException(
            status_code=400,
            detail=str(erro),
        ) from erro


# =========================================================
# 7. ANALISAR UMA SESSÃO SALVA
# =========================================================

@app.post("/analysis/sessoes/{id_fato}")
def analisar_sessao_salva(id_fato: int):
    try:
        sessao, historico = obter_sessao_e_historico(id_fato)

        if len(historico) < 2:
            return {
                "id_fato": id_fato,
                "id_usuario": sessao["id_usuario"],
                "status": "historico_insuficiente",
                "analise_personalizada": False,
                "sessoes_historicas_disponiveis": len(historico),
                "sessao_atual": {
                    "duracao_minutos": sessao["duracao_minutos"],
                    "quantidade_pausas": sessao["quantidade_pausas"],
                    "temperatura": sessao["temperatura"],
                    "umidade": sessao["umidade"],
                    "luminosidade": sessao["luminosidade"],
                    "ruido_db": sessao["ruido_db"],
                },
                "mensagem": (
                    "Histórico insuficiente para uma análise "
                    "estatística personalizada. Registre mais sessões."
                ),
            }

        # Recupera o limite de sessão escolhido pelo usuário.
        preferencias_usuario = obter_preferencias_usuario(
            sessao["id_usuario"]
        )

        dados_preferencias = (
            preferencias_usuario.get("preferencias", {})
            if preferencias_usuario is not None
            else {}
        )

        limite_minutos = dados_preferencias.get(
            "limite_minutos_sessao"
        )

        # Converte valores vindos do banco (inclusive strings) para
        # números. Zero/valores negativos são tratados como preferência
        # não configurada para evitar usar placeholders do Swagger.
        def preferencia_ambiental(nome: str) -> float | None:
            valor = dados_preferencias.get(nome)
            if valor is None or valor == "":
                return None
            try:
                numero = float(valor)
            except (TypeError, ValueError):
                return None
            if numero <= 0:
                return None
            return numero

        preferencia_temperatura = preferencia_ambiental(
            "preferencia_temperatura"
        )
        preferencia_luminosidade = preferencia_ambiental(
            "preferencia_luminosidade"
        )
        preferencia_ruido_db = preferencia_ambiental(
            "preferencia_ruido_db"
        )

        resultado = analisar_sessao(
            historico=historico,
            duracao_atual=sessao["duracao_minutos"],
            quantidade_pausas=sessao["quantidade_pausas"],
            temperatura=sessao["temperatura"],
            umidade=sessao["umidade"],
            luminosidade=sessao["luminosidade"],
            ruido_db=sessao["ruido_db"],
            limite_minutos=limite_minutos,
            preferencia_temperatura=preferencia_temperatura,
            preferencia_luminosidade=preferencia_luminosidade,
            preferencia_ruido_db=preferencia_ruido_db,
        )

        salvar_resultado_analise(id_fato, resultado)

        return {
            "id_fato": id_fato,
            "id_usuario": sessao["id_usuario"],
            "status": "analise_salva",
            "analise_personalizada": True,
            "historico_sessoes_utilizadas": len(historico),
            "resultado": resultado,
        }

    except ValueError as erro:
        raise HTTPException(
            status_code=400,
            detail=str(erro),
        ) from erro

    except Exception as erro:
        raise HTTPException(
            status_code=500,
            detail="Não foi possível analisar a sessão.",
        ) from erro


# =========================================================
# 8. CONSULTAR ANÁLISE SALVA
# =========================================================

@app.get("/analysis/sessoes/{id_fato}")
def consultar_analise_sessao(id_fato: int):
    if id_fato <= 0:
        raise HTTPException(
            status_code=400,
            detail="O ID da sessão deve ser positivo.",
        )

    try:
        with obter_conexao() as conexao:
            with conexao.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        id_fato,
                        id_usuario,
                        duracao_minutos,
                        classificacao,
                        score_anomalia,
                        score_contexto,
                        duracao_prevista,
                        probabilidade_prolongada,
                        recomendacao,
                        data_analise
                    FROM public.fato_ia
                    WHERE id_fato = %s;
                    """,
                    (id_fato,),
                )

                linha = cursor.fetchone()

                if linha is None:
                    raise HTTPException(
                        status_code=404,
                        detail="Sessão não encontrada.",
                    )

                colunas = [
                    "id_fato",
                    "id_usuario",
                    "duracao_minutos",
                    "classificacao",
                    "score_anomalia",
                    "score_contexto",
                    "duracao_prevista",
                    "probabilidade_prolongada",
                    "recomendacao",
                    "data_analise",
                ]

                return dict(zip(colunas, linha))

    except HTTPException:
        raise

    except Exception as erro:
        logger.exception(
            "Erro ao consultar análise salva: id_fato=%s",
            id_fato,
        )
        raise HTTPException(
            status_code=500,
            detail="Não foi possível consultar a análise salva.",
        ) from erro


# =========================================================
# 9. CONSULTAR TODAS AS SESSÕES DE UM USUÁRIO
# =========================================================

@app.get("/usuarios/{id_usuario}/sessoes")
def listar_sessoes_usuario(id_usuario: int):
    if id_usuario <= 0:
        raise HTTPException(
            status_code=400,
            detail="O ID do usuário deve ser positivo.",
        )

    try:
        with obter_conexao() as conexao:
            with conexao.cursor() as cursor:
                # Verifica se o usuário existe
                cursor.execute(
                    """
                    SELECT id_usuario
                    FROM public.dim_usuario
                    WHERE id_usuario = %s;
                    """,
                    (id_usuario,),
                )

                if cursor.fetchone() is None:
                    raise HTTPException(
                        status_code=404,
                        detail="Usuário não encontrado.",
                    )

                cursor.execute(
                    """
                    SELECT
                        id_fato,
                        id_usuario,
                        inicio,
                        fim,
                        duracao_minutos,
                        quantidade_pausas,
                        plataforma,
                        classificacao,
                        score_anomalia,
                        score_contexto,
                        duracao_prevista,
                        probabilidade_prolongada,
                        recomendacao,
                        data_analise
                    FROM public.fato_ia
                    WHERE id_usuario = %s
                    ORDER BY inicio DESC NULLS LAST, id_fato DESC;
                    """,
                    (id_usuario,),
                )

                colunas = [
                    descricao.name
                    for descricao in cursor.description
                ]

                sessoes = [
                    dict(zip(colunas, linha))
                    for linha in cursor.fetchall()
                ]

                return {
                    "id_usuario": id_usuario,
                    "total_sessoes": len(sessoes),
                    "sessoes": sessoes,
                }

    except HTTPException:
        raise

    except Exception as erro:
        raise HTTPException(
            status_code=500,
            detail="Não foi possível consultar as sessões do usuário.",
        ) from erro


# =========================================================
# 10. CONSULTAR HISTÓRICO DE ANÁLISES DE UM USUÁRIO
# =========================================================

@app.get("/analysis/historico/{id_usuario}")
def historico_analises_usuario(id_usuario: int):
    if id_usuario <= 0:
        raise HTTPException(
            status_code=400,
            detail="O ID do usuário deve ser positivo.",
        )

    try:
        with obter_conexao() as conexao:
            with conexao.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT id_usuario
                    FROM public.dim_usuario
                    WHERE id_usuario = %s;
                    """,
                    (id_usuario,),
                )

                if cursor.fetchone() is None:
                    raise HTTPException(
                        status_code=404,
                        detail="Usuário não encontrado.",
                    )

                cursor.execute(
                    """
                    SELECT
                        id_fato,
                        id_usuario,
                        inicio,
                        duracao_minutos,
                        classificacao,
                        score_anomalia,
                        score_contexto,
                        duracao_prevista,
                        probabilidade_prolongada,
                        recomendacao,
                        data_analise
                    FROM public.fato_ia
                    WHERE id_usuario = %s
                      AND data_analise IS NOT NULL
                    ORDER BY data_analise DESC, id_fato DESC;
                    """,
                    (id_usuario,),
                )

                colunas = [
                    descricao.name
                    for descricao in cursor.description
                ]

                analises = [
                    dict(zip(colunas, linha))
                    for linha in cursor.fetchall()
                ]

                return {
                    "id_usuario": id_usuario,
                    "total_analises": len(analises),
                    "analises": analises,
                }

    except HTTPException:
        raise

    except Exception as erro:
        raise HTTPException(
            status_code=500,
            detail="Não foi possível consultar o histórico de análises.",
        ) from erro


# =========================================================
# 11. RESUMO GERAL PARA O DASHBOARD
# =========================================================

@app.get("/dashboard/resumo")
def dashboard_resumo():
    try:
        with obter_conexao() as conexao:
            with conexao.cursor() as cursor:

                # Indicadores gerais
                cursor.execute(
                    """
                    SELECT
                        COUNT(*) AS total_sessoes,
                        COUNT(DISTINCT id_usuario) AS total_usuarios,
                        COALESCE(SUM(duracao_minutos), 0)
                            AS total_minutos,
                        AVG(duracao_minutos)
                            AS duracao_media,
                        COALESCE(SUM(quantidade_pausas), 0)
                            AS total_pausas,
                        COUNT(*) FILTER (
                            WHERE data_analise IS NOT NULL
                        ) AS total_analises
                    FROM public.fato_ia;
                    """
                )

                linha = cursor.fetchone()

                resumo = {
                    "total_sessoes": linha[0],
                    "total_usuarios": linha[1],
                    "total_minutos": linha[2],
                    "duracao_media": linha[3],
                    "total_pausas": linha[4],
                    "total_analises": linha[5],
                }

                # Distribuição por classificação
                cursor.execute(
                    """
                    SELECT
                        COALESCE(classificacao, 'sem_classificacao')
                            AS classificacao,
                        COUNT(*) AS quantidade
                    FROM public.fato_ia
                    GROUP BY COALESCE(
                        classificacao,
                        'sem_classificacao'
                    )
                    ORDER BY quantidade DESC;
                    """
                )

                distribuicao_classificacao = [
                    {
                        "classificacao": linha[0],
                        "quantidade": linha[1],
                    }
                    for linha in cursor.fetchall()
                ]

                # Evolução diária das sessões
                cursor.execute(
                    """
                    SELECT
                        inicio::date AS data,
                        COUNT(*) AS total_sessoes,
                        AVG(duracao_minutos) AS duracao_media
                    FROM public.fato_ia
                    WHERE inicio IS NOT NULL
                    GROUP BY inicio::date
                    ORDER BY data;
                    """
                )

                evolucao_diaria = [
                    {
                        "data": linha[0],
                        "total_sessoes": linha[1],
                        "duracao_media": linha[2],
                    }
                    for linha in cursor.fetchall()
                ]

                return {
                    "dashboard": "ANHANGÁ",
                    "resumo": resumo,
                    "distribuicao_classificacao": (
                        distribuicao_classificacao
                    ),
                    "evolucao_diaria": evolucao_diaria,
                }

    except Exception as erro:
        raise HTTPException(
            status_code=500,
            detail="Não foi possível gerar o resumo do dashboard.",
        ) from erro

@app.get("/usuarios/{id_usuario}/preferencias")
def consultar_preferencias(id_usuario: int):
    try:
        preferencias = obter_preferencias_usuario(id_usuario)

        if preferencias is None:
            raise HTTPException(
                status_code=404,
                detail="Usuário não encontrado."
            )

        return preferencias

    except HTTPException:
        raise
    except Exception as erro:
        logger.exception(
            "Erro ao consultar preferências do usuário."
        )
        raise HTTPException(
            status_code=500,
            detail="Não foi possível consultar as preferências."
        ) from erro


@app.put("/usuarios/{id_usuario}/preferencias")
def salvar_preferencias(
    id_usuario: int,
    preferencias: PreferenciasUsuarioUpdate
):
    try:
        dados = preferencias.model_dump(
            exclude_unset=True
        )

        resultado = atualizar_preferencias_usuario(
            id_usuario=id_usuario,
            preferencias=dados
        )

        return {
            "status": "preferencias_atualizadas",
            "preferencias": resultado
        }

    except ValueError as erro:
        raise HTTPException(
            status_code=400,
            detail=str(erro)
        ) from erro

    except LookupError as erro:
        raise HTTPException(
            status_code=404,
            detail=str(erro)
        ) from erro

    except Exception as erro:
        logger.exception(
            "Erro ao atualizar preferências do usuário."
        )
        raise HTTPException(
            status_code=500,
            detail="Não foi possível atualizar as preferências."
        ) from erro

