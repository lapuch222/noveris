
from datetime import datetime

from pydantic import BaseModel, Field, model_validator


class UsuarioCreate(BaseModel):
    nome: str = Field(min_length=1, max_length=100)
    perfil: str | None = None


class SessaoCreate(BaseModel):
    id_usuario: int = Field(gt=0)
    inicio: datetime
    fim: datetime | None = None

    duracao_minutos: float = Field(gt=0)
    quantidade_pausas: int = Field(default=0, ge=0)

    plataforma: str = Field(
        default="PC",
        min_length=1,
        max_length=50,
    )

    id_dispositivo: int | None = Field(
        default=None,
        gt=0,
    )

    # Dados ambientais
    temperatura: float | None = None
    umidade: float | None = Field(
        default=None,
        ge=0,
        le=100,
    )
    luminosidade: float | None = Field(
        default=None,
        ge=0,
    )
    ruido_db: float | None = Field(
        default=None,
        ge=0,
    )

    @model_validator(mode="after")
    def validar_datas(self):
        if self.fim is not None:
            if self.inicio.tzinfo != self.fim.tzinfo:
                raise ValueError(
                    "inicio e fim devem usar o mesmo padrão de fuso horário."
                )

            if self.fim < self.inicio:
                raise ValueError(
                    "fim não pode ser anterior a inicio."
                )

        return self


class AnaliseRequest(BaseModel):
    historico_minutos: list[float] = Field(min_length=2)
    duracao_atual: float = Field(gt=0)
    quantidade_pausas: int = Field(default=0, ge=0)

    temperatura: float | None = None
    umidade: float | None = Field(default=None, ge=0, le=100)
    luminosidade: float | None = Field(default=None, ge=0)
    ruido_db: float | None = Field(default=None, ge=0)


class PreferenciasUsuarioUpdate(BaseModel):
    # Preferências gerais
    limite_minutos_sessao: int | None = Field(
        default=None,
        ge=1,
        le=1440,
    )
    preferencia_luminosidade: float | None = Field(
        default=None,
        ge=0,
    )
    preferencia_temperatura: float | None = None
    preferencia_ruido_db: float | None = Field(
        default=None,
        ge=0,
    )

    # Preferências de acessibilidade
    usa_oculos: bool | None = None
    usa_lentes_contato: bool | None = None
    daltonismo: str | None = Field(default=None, max_length=100)
    autismo: bool | None = None
    deficiencia_intelectual: bool | None = None
    usa_libras: bool | None = None

    # Preferências de comunicação e ambiente
    preferencia_iluminacao: str | None = Field(
        default=None,
        max_length=100,
    )
    preferencia_comunicacao: str | None = Field(
        default=None,
        max_length=100,
    )
