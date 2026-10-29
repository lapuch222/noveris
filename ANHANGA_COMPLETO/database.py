
import os
import re

import psycopg
from dotenv import load_dotenv


# ============================================================
# 1. CONFIGURAÇÃO DO BANCO DE DADOS
# ============================================================

load_dotenv(override=True, encoding="utf-8-sig")


def obter_url_banco():
    url = os.getenv("DATABASE_URL")

    if not url:
        raise RuntimeError(
            "DATABASE_URL não configurada. Verifique o arquivo .env."
        )

    return url


def obter_conexao():
    return psycopg.connect(
        obter_url_banco(),
        connect_timeout=10,
    )


def testar_conexao():
    with obter_conexao() as conexao:
        with conexao.cursor() as cursor:
            cursor.execute("SELECT 1;")
            return cursor.fetchone() == (1,)


# ============================================================
# 2. CADASTRAR USUÁRIO
# ============================================================

def criar_usuario(nome, perfil=None):
    if not isinstance(nome, str) or not nome.strip():
        raise ValueError("O nome do usuário é obrigatório.")

    with obter_conexao() as conexao:
        with conexao.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO public.dim_usuario (
                    nome,
                    perfil,
                    data_cadastro,
                    status
                )
                VALUES (%s, %s, CURRENT_DATE, %s)
                RETURNING
                    id_usuario,
                    nome,
                    perfil,
                    data_cadastro,
                    status;
                """,
                (nome.strip(), perfil, "Ativo"),
            )

            linha = cursor.fetchone()

            return {
                "id_usuario": linha[0],
                "nome": linha[1],
                "perfil": linha[2],
                "data_cadastro": linha[3].isoformat(),
                "status": linha[4],
            }


# ============================================================
# 3. OBTER OU CADASTRAR DIM_TEMPO
# ============================================================

def obter_id_tempo(cursor, inicio):
    data_sessao = inicio.date()

    meses = [
        "Janeiro", "Fevereiro", "Março", "Abril",
        "Maio", "Junho", "Julho", "Agosto",
        "Setembro", "Outubro", "Novembro", "Dezembro",
    ]

    dias_semana = [
        "Segunda-feira",
        "Terça-feira",
        "Quarta-feira",
        "Quinta-feira",
        "Sexta-feira",
        "Sábado",
        "Domingo",
    ]

    hora = inicio.hour

    if 5 <= hora < 12:
        periodo = "Manhã"
    elif 12 <= hora < 18:
        periodo = "Tarde"
    elif 18 <= hora < 24:
        periodo = "Noite"
    else:
        periodo = "Madrugada"

    cursor.execute(
        """
        INSERT INTO public.dim_tempo (
            data,
            dia,
            mes,
            nome_mes,
            trimestre,
            ano,
            dia_semana,
            periodo_dia
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (data)
        DO UPDATE SET data = EXCLUDED.data
        RETURNING id_tempo;
        """,
        (
            data_sessao,
            data_sessao.day,
            data_sessao.month,
            meses[data_sessao.month - 1],
            (data_sessao.month - 1) // 3 + 1,
            data_sessao.year,
            dias_semana[data_sessao.weekday()],
            periodo,
        ),
    )

    return cursor.fetchone()[0]


# ============================================================
# 4. OBTER OU CADASTRAR DIM_DISPOSITIVO
# ============================================================

def obter_id_dispositivo(cursor, plataforma):
    if not isinstance(plataforma, str) or not plataforma.strip():
        raise ValueError("A plataforma é obrigatória.")

    plataforma = plataforma.strip()
    slug = re.sub(
        r"[^A-Za-z0-9_-]",
        "_",
        plataforma.upper(),
    )[:35]

    serial = f"ANHANGA-API-{slug}"

    cursor.execute(
        """
        INSERT INTO public.dim_dispositivo (
            serial_number,
            tipo_dispositivo,
            modelo,
            fabricante,
            conectividade,
            status
        )
        VALUES (%s, %s, %s, %s, %s, %s)
        ON CONFLICT (serial_number)
        DO UPDATE SET serial_number = EXCLUDED.serial_number
        RETURNING id_dispositivo;
        """,
        (
            serial,
            plataforma,
            "Dispositivo cadastrado pela API",
            "NOVERIS",
            "API",
            "Ativo",
        ),
    )

    return cursor.fetchone()[0]


# ============================================================
# 5. REGISTRAR SESSÃO COM DADOS AMBIENTAIS
# ============================================================

def registrar_sessao(
    id_usuario,
    inicio,
    fim,
    duracao_minutos,
    quantidade_pausas,
    plataforma="PC",
    id_dispositivo=None,
    temperatura=None,
    umidade=None,
    luminosidade=None,
    ruido_db=None,
):
    if duracao_minutos is None or duracao_minutos <= 0:
        raise ValueError(
            "A duração da sessão deve ser maior que zero."
        )

    if quantidade_pausas < 0:
        raise ValueError(
            "A quantidade de pausas não pode ser negativa."
        )

    if fim is not None:
        if inicio.tzinfo != fim.tzinfo:
            raise ValueError(
                "inicio e fim devem usar o mesmo padrão de fuso horário."
            )

        if fim < inicio:
            raise ValueError(
                "fim não pode ser anterior a inicio."
            )

    if temperatura is not None and not -50 <= temperatura <= 80:
        raise ValueError("Temperatura fora do intervalo permitido.")

    if umidade is not None and not 0 <= umidade <= 100:
        raise ValueError("Umidade deve estar entre 0 e 100.")

    if luminosidade is not None and luminosidade < 0:
        raise ValueError("Luminosidade não pode ser negativa.")

    if ruido_db is not None and ruido_db < 0:
        raise ValueError("Ruído não pode ser negativo.")

    if not isinstance(plataforma, str) or not plataforma.strip():
        raise ValueError("A plataforma é obrigatória.")

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
                raise ValueError(
                    f"Usuário {id_usuario} não encontrado."
                )

            id_tempo = obter_id_tempo(cursor, inicio)

            if id_dispositivo is None:
                id_dispositivo = obter_id_dispositivo(
                    cursor,
                    plataforma,
                )
            else:
                cursor.execute(
                    """
                    SELECT id_dispositivo
                    FROM public.dim_dispositivo
                    WHERE id_dispositivo = %s;
                    """,
                    (id_dispositivo,),
                )

                if cursor.fetchone() is None:
                    raise ValueError(
                        f"Dispositivo {id_dispositivo} não encontrado."
                    )

            cursor.execute(
                """
                INSERT INTO public.fato_ia (
                    id_usuario,
                    id_tempo,
                    id_dispositivo,
                    plataforma,
                    inicio,
                    fim,
                    duracao_minutos,
                    quantidade_pausas,
                    temperatura,
                    umidade,
                    luminosidade,
                    ruido_db
                )
                VALUES (
                    %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s
                )
                RETURNING id_fato;
                """,
                (
                    id_usuario,
                    id_tempo,
                    id_dispositivo,
                    plataforma.strip(),
                    inicio,
                    fim,
                    duracao_minutos,
                    quantidade_pausas,
                    temperatura,
                    umidade,
                    luminosidade,
                    ruido_db,
                ),
            )

            id_fato = cursor.fetchone()[0]

            return {
                "id_fato": id_fato,
                "id_usuario": id_usuario,
                "id_tempo": id_tempo,
                "id_dispositivo": id_dispositivo,
                "plataforma": plataforma.strip(),
                "duracao_minutos": duracao_minutos,
                "quantidade_pausas": quantidade_pausas,
                "temperatura": temperatura,
                "umidade": umidade,
                "luminosidade": luminosidade,
                "ruido_db": ruido_db,
                "status": "sessao_salva",
            }


# ============================================================
# 6. OBTER UMA SESSÃO E SEU HISTÓRICO
# ============================================================

def obter_sessao_e_historico(id_fato, limite=30):
    if (
        isinstance(id_fato, bool)
        or not isinstance(id_fato, int)
        or id_fato <= 0
    ):
        raise ValueError(
            "O ID da sessão deve ser um inteiro positivo."
        )

    if (
        isinstance(limite, bool)
        or not isinstance(limite, int)
        or not 2 <= limite <= 100
    ):
        raise ValueError(
            "O limite deve estar entre 2 e 100 sessões."
        )

    with obter_conexao() as conexao:
        with conexao.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    id_fato,
                    id_usuario,
                    duracao_minutos,
                    quantidade_pausas,
                    temperatura,
                    umidade,
                    luminosidade,
                    ruido_db
                FROM public.fato_ia
                WHERE id_fato = %s;
                """,
                (id_fato,),
            )

            linha = cursor.fetchone()

            if linha is None:
                raise ValueError(
                    f"Sessão {id_fato} não encontrada."
                )

            sessao = {
                "id_fato": linha[0],
                "id_usuario": linha[1],
                "duracao_minutos": (
                    float(linha[2])
                    if linha[2] is not None
                    else None
                ),
                "quantidade_pausas": linha[3] or 0,
                "temperatura": (
                    float(linha[4])
                    if linha[4] is not None
                    else None
                ),
                "umidade": (
                    float(linha[5])
                    if linha[5] is not None
                    else None
                ),
                "luminosidade": (
                    float(linha[6])
                    if linha[6] is not None
                    else None
                ),
                "ruido_db": (
                    float(linha[7])
                    if linha[7] is not None
                    else None
                ),
            }

            if (
                sessao["duracao_minutos"] is None
                or sessao["duracao_minutos"] <= 0
            ):
                raise ValueError(
                    "A sessão precisa ter duração maior que zero."
                )

            cursor.execute(
                """
                SELECT duracao_minutos
                FROM public.fato_ia
                WHERE id_usuario = %s
                  AND id_fato <> %s
                  AND duracao_minutos > 0
                ORDER BY inicio DESC NULLS LAST, id_fato DESC
                LIMIT %s;
                """,
                (
                    sessao["id_usuario"],
                    id_fato,
                    limite,
                ),
            )

            linhas_historico = cursor.fetchall()

            # O resultado da consulta está do mais recente
            # para o mais antigo. Invertemos para obter ordem cronológica.
            historico = [
                float(item[0])
                for item in reversed(linhas_historico)
            ]

            return sessao, historico


# ============================================================
# 7. SALVAR RESULTADO DA ANÁLISE
# ============================================================

def salvar_resultado_analise(id_fato, resultado):
    campos_obrigatorios = [
        "classificacao",
        "score_anomalia",
        "score_contexto",
        "duracao_prevista",
        "probabilidade_prolongada",
        "recomendacao",
    ]

    for campo in campos_obrigatorios:
        if campo not in resultado:
            raise ValueError(
                f"Campo obrigatório ausente na análise: {campo}"
            )

    with obter_conexao() as conexao:
        with conexao.cursor() as cursor:
            cursor.execute(
                """
                UPDATE public.fato_ia
                SET
                    classificacao = %s,
                    score_anomalia = %s,
                    score_contexto = %s,
                    duracao_prevista = %s,
                    probabilidade_prolongada = %s,
                    recomendacao = %s,
                    data_analise = CURRENT_TIMESTAMP
                WHERE id_fato = %s
                RETURNING id_fato;
                """,
                (
                    resultado["classificacao"],
                    resultado["score_anomalia"],
                    resultado["score_contexto"],
                    resultado["duracao_prevista"],
                    resultado["probabilidade_prolongada"],
                    resultado["recomendacao"],
                    id_fato,
                ),
            )

            linha = cursor.fetchone()

            if linha is None:
                raise ValueError(
                    f"Sessão {id_fato} não encontrada."
                )

            return linha[0]


# ============================================================
# 8. CONSULTAR PREFERÊNCIAS DO USUÁRIO
# ============================================================

COLUNAS_PREFERENCIAS = {
    "limite_minutos_sessao": "limite_minutos_sessao",
    "preferencia_luminosidade": "preferencia_luminosidade",
    "preferencia_temperatura": "temperatura_preferida",
    "preferencia_ruido_db": "ruido_maximo_db",
    "usa_oculos": "usa_oculos",
    "usa_lentes_contato": "usa_lente_contato",
    "daltonismo": "tipo_daltonismo",
    "autismo": "autismo",
    "deficiencia_intelectual": "deficiencia_intelectual",
    "usa_libras": "preferencia_libras",
    "preferencia_iluminacao": "modo_iluminacao",
    "preferencia_comunicacao": "preferencia_comunicacao",
}



def obter_preferencias_usuario(id_usuario):
    if (
        isinstance(id_usuario, bool)
        or not isinstance(id_usuario, int)
        or id_usuario <= 0
    ):
        raise ValueError(
            "O ID do usuário deve ser um inteiro positivo."
        )

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
                return None

            colunas_sql = ", ".join(
                sorted(set(COLUNAS_PREFERENCIAS.values()))
            )

            cursor.execute(
                f"""
                SELECT {colunas_sql}
                FROM public.dim_usuario
                WHERE id_usuario = %s;
                """,
                (id_usuario,),
            )

            linha = cursor.fetchone()
            colunas = [
                descricao.name
                for descricao in cursor.description
            ]

            dados_banco = dict(zip(colunas, linha))

            preferencias = {
                nome_api: dados_banco.get(nome_banco)
                for nome_api, nome_banco
                in COLUNAS_PREFERENCIAS.items()
            }

            valor_libras = preferencias["usa_libras"]
            if isinstance(valor_libras, str):
                preferencias["usa_libras"] = (
                    valor_libras.strip().lower()
                    in ("sim", "true", "1", "libras")
                )

            return {
                "id_usuario": id_usuario,
                "preferencias": preferencias,
            }


def atualizar_preferencias_usuario(
    id_usuario,
    preferencias,
):
    if (
        isinstance(id_usuario, bool)
        or not isinstance(id_usuario, int)
        or id_usuario <= 0
    ):
        raise ValueError(
            "O ID do usuário deve ser um inteiro positivo."
        )

    if not isinstance(preferencias, dict):
        raise ValueError(
            "As preferências devem ser fornecidas em um dicionário."
        )

    campos = {
        COLUNAS_PREFERENCIAS[chave]: valor
        for chave, valor in preferencias.items()
        if chave in COLUNAS_PREFERENCIAS
    }

    # Converte a preferência booleana para o formato textual
    # utilizado pela coluna preferencia_libras.
    if "preferencia_libras" in campos:
        valor = campos["preferencia_libras"]
        if isinstance(valor, bool):
            campos["preferencia_libras"] = (
                "sim" if valor else "não"
            )

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
                raise LookupError(
                    f"Usuário {id_usuario} não encontrado."
                )

            if campos:
                assignments = ", ".join(
                    f"{coluna} = %s"
                    for coluna in campos
                )

                valores = list(campos.values())
                valores.append(id_usuario)

                cursor.execute(
                    f"""
                    UPDATE public.dim_usuario
                    SET {assignments}
                    WHERE id_usuario = %s;
                    """,
                    valores,
                )

    resultado = obter_preferencias_usuario(id_usuario)

    return resultado["preferencias"]
