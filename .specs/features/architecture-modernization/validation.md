# Modernização arquitetural incremental — validação

**Feature:** `architecture-modernization`
**Data de início:** 2026-08-09
**Branch:** `feature/melhorando-estrutura`
**Baseline commit:** `556e77d`

Este relatório é atualizado durante a execução das tarefas T01–T22. Evidências
dinâmicas só são registradas após execução real dos comandos. Build, suíte,
replay e pacote não comprovam trackpad físico, permissões TCC, assinatura
Developer ID ou notarização.

## Baseline — T01

Estado medido antes de alterações de produto:

| Evidência | Resultado |
|---|---|
| Branch | `feature/melhorando-estrutura` |
| Alterações prévias | Somente preparação documental/regras, consolidada em `556e77d` |
| `git diff --check` | PASS |
| `swift build --disable-sandbox --product AirShortcut` | PASS |
| `swift test --disable-sandbox` | PASS — 111 testes, 0 falhas |
| `AIRSHORTCUT_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package` | PASS — 111 testes, 0 falhas; 8 regressões de segurança; pacote ad hoc verificado |
| Avisos | SwiftPM reportou os cinco `AGENTS.md` especializados como arquivos não tratados do target |
| Trackpad físico | NOT-RUN |
| TCC | NOT-RUN |
| Developer ID | NOT-RUN — pacote baseline é ad hoc |
| Notarização | NOT-RUN |

### T01 — resultado

**Status:** ✅ concluída.

Baseline reproduzível registrado antes da implementação. Nenhum código de
produto foi alterado nesta tarefa.

## Execução por tarefa

| Tarefa | Status | Evidência/commit |
|---|---|---|
| T01 | ✅ | Baseline acima; commit pendente de integração |
| T02 | ⏳ | — |
| T03 | ⏳ | — |
| T04 | ⏳ | — |
| T05 | ⏳ | — |
| T06 | ⏳ | — |
| T07 | ⏳ | — |
| T08 | ⏳ | — |
| T09 | ⏳ | — |
| T10 | ⏳ | — |
| T11 | ⏳ | — |
| T12 | ⏳ | — |
| T13 | ⏳ | — |
| T14 | ⏳ | — |
| T15 | ⏳ | — |
| T16 | ⏳ | — |
| T17 | ⏳ | — |
| T18 | ⏳ | — |
| T19 | ⏳ | — |
| T20 | ⏳ | — |
| T21 | ⏳ | — |
| T22 | ⏳ | — |

## Gates e limites

As tabelas de gates de fase, rastreabilidade ARCH-01–ARCH-10, auditoria de
concorrência, sensor de discriminação e UAT serão preenchidas após as
respectivas fases, com comandos e resultados reais.
