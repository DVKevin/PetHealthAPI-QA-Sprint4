# 🐾 Pet Health API — Sprint 4: Compliance, Quality Assurance & Tests

Entrega da 4ª Sprint de **Compliance, Quality Assurance & Tests** (FIAP 2026) — testes manuais de sistema no Azure Test Plans e automação de testes da Pet Health API (.NET 8 + Oracle).

## 🔗 Links da entrega

| Item                                                     | Link                                               |
| -------------------------------------------------------- | -------------------------------------------------- |
| Azure Boards / Test Plans (Overview → Summary)           | https://dev.azure.com/pethealth-fiap/Pet%20Health  |
| Vídeo da automação (configuração, execução e resultados) | **COLE_AQUI_O_LINK_DO_VIDEO**                      |
| Código da API testada                                    | https://github.com/DVKevin/PetHealthAPI-DevOps-sp3 |

## 👥 Integrantes

| Nome                       | RM     |
| -------------------------- | ------ |
| Kevin Martins Campos       | 563454 |
| Matheus Arazin de Oliveira | 556649 |
| Artur Pioli Silva          | 565597 |
| Pedro Gabriel Claes        | 566058 |

## Parte A — Testes manuais de sistema (Azure Test Plans)

- **4 Test Plans**, um por sprint (`Pet Health – Sprint 1` a `Sprint 4`), alinhados às sprints do plano de release no Azure Boards.
- **14 suítes**, uma por PBI (requirement-based, ligadas ao PBI no Boards).
- **24 casos de teste** com objetivo, pré-condições, ambiente, critério de aceite, passos, resultados esperados e dados de entrada/saída em **Parameter values** (dados controlados).
- Relatório de execução de cada plano com os gráficos **Outcome** e **Run By**.

| Sprint (Azure Boards)                            | PBIs                                                                                                                                  | Casos     | Resultado            |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- | --------- | -------------------- |
| Sprint 1 — Cadastro, histórico clínico e vacinas | 1 Cadastro do pet · 2 Editar dados do pet · 3 Registrar vacinas · 4 Carteira de vacinação · 5 Histórico clínico · 6 API segura (LGPD) | CT01–CT15 | 15 Passed            |
| Sprint 2 — Gamificação, check-ins e notificações | 7 Lembretes inteligentes · 8 Check-ins · 9 XP e medalhas · 10 Dashboard                                                               | CT16–CT20 | 2 Passed · 3 Blocked |
| Sprint 3 — Compartilhamento social e ranking     | 11 Compartilhamento social · 12 Ranking de tutores                                                                                    | CT21–CT22 | 2 Blocked            |
| Sprint 4 — Marketplace, parceiros e cashback     | 13 Marketplace de parceiros · 14 Cashback                                                                                             | CT23–CT24 | 2 Blocked            |

**Versão testada:** [PetHealthAPI-DevOps-sp3](https://github.com/DVKevin/PetHealthAPI-DevOps-sp3), executada localmente via `docker compose` (API .NET 8 + Oracle XE 21), Swagger em `http://localhost:8080`.

**Execução (04/11/2026):** CT01 executado passo a passo no Test Runner do Azure; CT02–CT17 executados contra a API pelo script [`scripts/executar-testes-sistema.sh`](scripts/executar-testes-sistema.sh) — **72 verificações aprovadas, 0 reprovadas** ([evidência](evidencias/execucao-testes-sistema.txt)). CT18–CT24 marcados como **Blocked** (PBIs ainda não liberados para teste).

## Parte B — Automação de testes

A API não possui interface gráfica, então a automação usa **Postman** (testes de integração) e **JMeter** (teste de desempenho).

### Postman — 15 casos de teste de integração

Arquivos em [`postman/`](postman/). A coleção usa dados controlados (environment `PetHealth - Local`), limpa os próprios dados no início e no fim (pode ser executada várias vezes) e valida tempo de resposta < 2000 ms em todas as requisições.

| Teste | PBI  | O que valida                                                |
| ----- | ---- | ----------------------------------------------------------- |
| TC01  | 1    | Cadastro de tutor válido → 201, id, dados e header Location |
| TC02  | 1    | E-mail duplicado → 400 com mensagem                         |
| TC03  | 1    | Cadastro de pet vinculado ao tutor → 201                    |
| TC04  | 1    | Pet com peso 0 → 400 (faixa 0.1–200 kg)                     |
| TC05  | 1    | Pet de tutor inexistente → 400                              |
| TC06  | 2    | Edição do pet → 204                                         |
| TC07  | 2, 6 | Edição persistida + X-Correlation-ID devolvido              |
| TC08  | 3    | Registro de vacina (próxima dose = hoje + 10 dias) → 201    |
| TC09  | 4    | Carteira com 1 vacina, sem dados do tutor                   |
| TC10  | 7    | Vacina aparece em "vencendo" (30 dias)                      |
| TC11  | 5    | Registro de consulta (retorno = hoje + 7 dias) → 201        |
| TC12  | 7    | Consulta aparece em "retornos"                              |
| TC13  | 6    | Erro 404 sem stack trace, Oracle ou nomes de tabela         |
| TC14  | —    | Exclusão do tutor de teste → 204                            |
| TC15  | —    | Exclusão em cascata: pet removido → 404                     |

Como executar:

1. Suba a API (`docker compose up -d --build` no repositório da API e crie o schema com `script_bd.sql`).
2. Postman → **Import** dos dois arquivos de `postman/` → selecione o environment **PetHealth - Local**.
3. Direito na coleção → **Run collection** → **Run**.

Ou pela linha de comando:

```bash
npx newman run postman/PetHealthAPI-Sprint4.postman_collection.json \
  -e postman/PetHealth-Local.postman_environment.json \
  -r cli,junit --reporter-junit-export evidencias/newman-resultado.xml
```

### JMeter — teste de desempenho (complementar, opcional)

Arquivo [`jmeter/PetHealthAPI-Desempenho.jmx`](jmeter/PetHealthAPI-Desempenho.jmx): 20 usuários, ramp-up de 10 s, 10 repetições de 4 consultas (Pets, Tutores, Vacinas vencendo, Retornos) = 800 requisições, com Response Assertion (HTTP 200) e Duration Assertion (2000 ms).

Critérios de aceite: **0% de erro**, **P90 < 2000 ms**, **Apdex ≥ 0,90** (T = 500 ms, F = 1500 ms).

```bash
jmeter -n -t jmeter/PetHealthAPI-Desempenho.jmx \
  -l evidencias/jmeter-resultado.jtl -e -o evidencias/jmeter-relatorio \
  -Jjmeter.reportgenerator.sample_filter="^(?!WARMUP).*"
```

Parâmetros opcionais: `-Jhost=… -Jport=… -Jusuarios=… -Jrampup=… -Jrepeticoes=…`.

### Resultados obtidos

| Ferramenta                  | Resultado                                                                         |
| --------------------------- | --------------------------------------------------------------------------------- |
| Postman (Collection Runner) | 16 requisições · **50 testes aprovados · 0 falhas · 0 erros** · tempo médio 19 ms |

Evidências em [`evidencias/`](evidencias/):

| Arquivo                                       | Conteúdo                                           |
| --------------------------------------------- | -------------------------------------------------- |
| `grafico-sprint1.png` … `grafico-sprint4.png` | Gráficos Outcome e Run By de cada Test Plan        |
| `execucao-testes-sistema.txt`                 | Saída da execução dos casos CT02–CT17 contra a API |
| `postman-resultado.png`                       | Resultado do Collection Runner do Postman          |

## 📁 Estrutura

```
├── README.md
├── postman/
│   ├── PetHealthAPI-Sprint4.postman_collection.json
│   └── PetHealth-Local.postman_environment.json
├── jmeter/
│   └── PetHealthAPI-Desempenho.jmx
├── scripts/
│   └── executar-testes-sistema.sh   # execução dos casos de teste de sistema CT02–CT17
└── evidencias/                      # gráficos, saída da execução e resultado do Postman
```
