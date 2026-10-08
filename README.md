<div align="center">

  <!-- Logo da Empresa (NOVERIS) -->
  <img src="./assets/noveris-logo.png" alt="NOVERIS Logo" width="280"/>
  
  <p><b>A P R E S E N T A</b></p>

  <!-- Banner/Logo da IA (ANHANGÁ) -->
  <img src="./assets/anhanga-banner.png" alt="NOVERIS Anhangá Logo" width="380"/>

  # 🦅 ANHANGÁ
  ### Análise Neural de Hábitos, Ambiente e Gaming Adaptativo

  *Uma nova forma de compreender a experiência de gaming por meio da Inteligência Artificial.*

  <p>
    <a href="#-o-que-é-o-anhangá">Sobre</a> •
    <a href="#-curiosidade-por-que-o-nome-anhangá">Curiosidade</a> •
    <a href="#-como-funciona">Como Funciona</a> •
    <a href="#-o-que-o-sistema-analisa">Métricas</a> •
    <a href="#-matemática-aplicada">Matemática</a> •
    <a href="#-engenharia-de-dados">Engenharia de Dados</a> •
    <a href="#-smart-home-2050">Smart Home</a> •
    <a href="#-acessibilidade--experiência-personalizada">Acessibilidade</a> •
    <a href="#-tecnologias">Tecnologias</a>
  </p>

  <!-- Badges de Status e Contexto Institucional -->
  <p>
    <img src="https://img.shields.io/badge/Contexto-Smart_Home_2050-7B2CBF?style=for-the-badge&logo=iot&logoColor=white" alt="Smart Home 2050">
    <img src="https://img.shields.io/badge/Missão-ExpoTech_2026.2-00F2FE?style=for-the-badge&logo=rocket&logoColor=black" alt="ExpoTech 2026.2">
    <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License">
  </p>
  <p>
    <img src="https://img.shields.io/badge/Python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python">
    <img src="https://img.shields.io/badge/FastAPI-0.100+-009688?style=for-the-badge&logo=fastapi&logoColor=white" alt="FastAPI">
    <img src="https://img.shields.io/badge/Database-PostgreSQL_/_Supabase-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL">
  </p>

</div>

---

## 🎯 O que é o ANHANGÁ?

O **ANHANGÁ**, desenvolvido pela **NOVERIS**, é uma solução de Inteligência Artificial voltada para ambientes inteligentes que analisa sessões de gaming, aprende os padrões individuais do usuário e oferece recomendações personalizadas de acordo com seu comportamento, preferências e contexto.

O sistema transforma dados de uma sessão de gaming em informações inteligentes, acompanhando o comportamento histórico do usuário para identificar quando uma nova sessão apresenta uma diferença significativa em relação ao seu padrão habitual, integrando também variáveis ambientais do seu espaço doméstico.

---

## 💡 Curiosidade: Por que o nome ANHANGÁ?

> Na mitologia e no folclore brasileiro, o **Anhangá** é reconhecido como o espírito protetor da fauna, da flora e das matas. Ele não é uma figura punitiva, mas sim um **guardião invisível e adaptativo** que preserva o equilíbrio do ecossistema.

A **NOVERIS** escolheu esse nome para simbolizar a essência do projeto: uma Inteligência Artificial que atua como uma **guarda silenciosa sobre o ambiente doméstico do jogador**, monitorando variáveis em tempo real sem interromper a imersão, garantindo o equilíbrio entre alta performance em gaming e saúde/bem-estar na Smart Home 2050.

---

## 🧠 Como Funciona?

O ANHANGÁ combina diferentes etapas de Inteligência Artificial e Engenharia de Dados através do fluxo:

$$\text{Dados} \longrightarrow \text{Processamento} \longrightarrow \text{Machine Learning} \longrightarrow \text{Análise de Contexto} \longrightarrow \text{IA Generativa} \longrightarrow \text{Recomendação}$$

### Principais Etapas do Sistema:
- **Coleta de dados:** Captação contínua da duração da sessão e telemetria do ambiente.
- **Organização e Processamento:** Estruturação dos dados telemétricos para análise estatística.
- **Aprendizado de Padrões:** Definição da linha de base (*baseline*) comportamental do usuário.
- **Identificação de Anomalias:** Detecção de comportamentos fora do padrão histórico.
- **Análise Multicontextual:** Cruzamento entre hábitos de jogo, variáveis ambientais e agenda do usuário.
- **IA Generativa & Comunicação:** Tradução de diagnósticos numéricos em recomendações conversacionais e personalizadas.

---

## 🎮 Inteligência para Cada Jogador

O ANHANGÁ **não utiliza apenas um limite fixo universal de tempo** (como `if duracao > 120`). Cada pessoa possui um hábito único: uma sessão de 3 horas pode ser comum para um jogador e completamente atípica para outro.

Por isso, o ANHANGÁ utiliza o histórico individual para responder:
> **“O que é normal para este usuário?”**

---

## 📊 O que o Sistema Analisa?

| Camada | Variáveis Analisadas |
| :--- | :--- |
| **🕹️ Sessão de Gaming** | Duração da sessão, horário de início, quantidade de pausas, histórico de sessões e dispositivo utilizado. |
| **🌡️ Telemetria Ambiental** | Temperatura do cômodo, umidade, luminosidade (lux), nível de ruído (dB) e presença no ambiente. |
| **📅 Perfil & Agenda** | Preferências do usuário, configurações de acessibilidade e compromissos cadastrados na rotina. |

---

## 🧮 Matemática Aplicada & Indicadores

A inteligência do ANHANGÁ utiliza métodos estatísticos para transformar impressões em dados mensuráveis:

- **Média ($\mu$) & Mediana:** Identificação da tendência central do histórico do usuário.
- **Desvio Padrão ($\sigma$):** Medição da variabilidade habitual do jogador.
- **Z-Score ($Z$):** Cálculo exato da distância estatística da sessão atual em relação ao histórico:
  $$Z = \frac{X - \mu}{\sigma}$$
- **Score de Anomalia & Contexto:** Métricas ponderadas que correlacionam o desvio de tempo com os sensores de ambiente.
- **Previsão & Probabilidade:** Estimativa do tempo provável de prolongamento da sessão.

---

## 🤖 Machine Learning + IA Generativa

O ANHANGÁ divide a inteligência em duas funções complementares:

* **Machine Learning:** Encontra o padrão estatístico e detecta a diferença quantitativa (*"Esta sessão está muito acima do seu padrão habitual"*).
* **IA Generativa:** Transforma o resultado da análise em uma comunicação amigável, clara e contextualizada:

> 💡 *"Sua sessão atual está muito acima da sua duração habitual. Como você possui um compromisso próximo, considere fazer uma pausa ou encerrar a sessão."*

---

## 🏠 Smart Home 2050

O **ANHANGÁ** atua como uma central inteligente capaz de interagir com dispositivos compatíveis no ambiente doméstico:

- 📱 **Smartphone:** Envio de alertas em linguagem natural e notificações.
- 💻 **Computador / Console / TV / Monitor:** Ajustes de perfil de iluminação e brilho da tela.
- 💡 **Luminária Inteligente:** Adaptação da luz do cômodo para redução de fadiga visual.
- ❄️ **Ar-condicionado:** Ajuste preditivo do climatizador durante sessões longas.

🔒 **Privacidade & Controle:** O usuário mantém total controle sobre quais dispositivos a IA tem permissão para ajustar e quais automações podem ser realizadas.

---

## ♿ Acessibilidade & Experiência Personalizada

O sistema permite configurar preferências para garantir uma experiência previsível e confortável:

- **Ajustes Visuais:** Controle de luminosidade, contraste, tamanho de texto e sensibilidade a cores/movimentos.
- **Alertas Customizados:** Modos visuais, sonoros e hápticos com intensidade ajustável.
- **Acessibilidade:** Suporte à comunicação e adaptação de alertas para Libras.
- **Redução de Estímulos:** Suavização automática de brilho e som ao detectar fadiga.

---

## 🏗️ Engenharia de Dados

A arquitetura de dados é estruturada no fluxo telemétrico de ponta a ponta:

$$\mathbf{SOURCE} \longrightarrow \mathbf{INGESTION} \longrightarrow \mathbf{PROCESSING} \longrightarrow \mathbf{STORAGE} \longrightarrow \mathbf{CONSUMPTION}$$

1. **SOURCE:** Captura de dados brutos da aplicação, sessões, dispositivos IoT e ambiente.
2. **INGESTION:** Entrada e organização telemétrica dos eventos em tempo real.
3. **PROCESSING:** Tratamento, transformação e geração de indicadores estatísticos.
4. **STORAGE:** Armazenamento estruturado e relacional dos dados historizados.
5. **CONSUMPTION:** Exibição em Dashboards, respostas da IA Generativa e gatilhos de automação.

---

## 🚀 Tecnologias

- **Python 3.11+:** Processamento de dados e inteligência do sistema.
- **FastAPI:** Backend assíncrono para disponibilização dos serviços da aplicação.
- **Pandas & NumPy:** Tratamento, manipulação e cálculo estatístico de arrays.
- **Scikit-learn:** Modelos de Machine Learning e detecção de padrões/anomalias.
- **PostgreSQL / Supabase:** Banco de dados relacional para armazenamento seguro.
- **Git / GitHub Pages:** Controle de versão e publicação do showcase institucional.

---

## 🌐 A Visão da NOVERIS

A **NOVERIS** acredita que a próxima geração de Smart Homes não será baseada apenas em dispositivos conectados. Será baseada em ambientes que compreendem contexto, aprendem padrões e se adaptam às pessoas. O **ANHANGÁ** representa essa visão aplicada ao universo gamer.

---

<div align="center">
  <p><b>🦅 ANHANGÁ — Inteligência que entende seu contexto.</b></p>
  <p>NOVERIS • ExpoTech 2026.2 • Missão 2050 🌌</p>
</div>

---

<div align="center">
  <p><b>🦅 ANHANGÁ — Inteligência que entende seu contexto.</b></p>
  <p>NOVERIS • ExpoTech 2026.2 • Missão 2050 🌌</p>
</div>
