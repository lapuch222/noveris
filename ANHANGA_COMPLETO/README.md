# ANHANGÁ — Python

NOVERIS apresenta ANHANGÁ — Análise Neural de Hábitos, Ambiente e Gaming Adaptativo.

## Estrutura

main.py — API FastAPI
database.py — PostgreSQL/Supabase
models.py — entidades
schemas.py — validação
analysis.py — matemática, estatística e análise
ai.py — prompts e IA Generativa
data/ — dados de teste
tests/ — testes

## Fluxo

Aplicativo → FastAPI → análise matemática/ML → IA → recomendação → Supabase

## Executar

python -m venv .venv

Windows:
.venv\Scripts\activate

pip install -r requirements.txt

Crie `.env` usando `.env.example`.

uvicorn main:app --reload

Documentação:
http://127.0.0.1:8000/docs

## Exemplo POST /analysis

{
  "historico_minutos": [80, 95, 100, 85, 110],
  "duracao_atual": 240,
  "quantidade_pausas": 2,
  "temperatura": 24,
  "umidade": 55,
  "luminosidade": 300,
  "ruido_db": 45
}

A primeira versão usa baselines estatísticos. O modelo de Machine Learning treinado será incorporado após termos dados suficientes para treinamento e avaliação.
