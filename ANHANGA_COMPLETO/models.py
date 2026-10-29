from dataclasses import dataclass
from datetime import datetime

@dataclass
class Usuario:
    id_usuario: int | None
    nome: str
    perfil: str | None = None

@dataclass
class SessaoGaming:
    id_usuario: int
    inicio: datetime
    fim: datetime | None
    duracao_minutos: float
    quantidade_pausas: int
