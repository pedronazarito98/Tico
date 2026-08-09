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
| T02 | ✅ | Mapa de seams em `design.md` e evidências abaixo; commit pendente |
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

## T02 — mapa de dependências e ownership

**Arquivos alterados:** somente `design.md` e este relatório.

| Seam | Produtor | Consumidores | Efeitos | Owner observado |
|---|---|---|---|---|
| `RuleEditorView` | `Views/RulesView.swift:35-58` | `Views/ContentView.swift:168-189` → `RulesView` | closures de save/conflito/preset e captura; nenhum IO direto | `@State` local em `RuleEditorView.swift:27-32`; sessão explícita ainda inexistente |
| `ShortcutStore` | `App/AirShortcutApp.swift:17-24` | `ContentView`, `RulesView`, `ProfilesView`, `GestureLibraryView`, `MenuBarContentView` | leitura/migração, JSON, backup, escrita atômica, import/export | `ObservableObject` publica coleções e coordena invariantes, mas ainda contém IO |
| `AppController` | `App/AirShortcutApp.swift:29-38` | `ContentView`, `MenuBarContentView`, teste de segurança | captura global/trackpad, laboratório, automação, catálogo e tarefas | `@MainActor` em `Support/AppController.swift:12`; fachada temporária compatível |

**Resultado:** o design documenta o grafo observável e não encontrou ciclos ou
consumidores ocultos que exijam mudar contratos antes de T04/T10/T13. Os três
seams permanecem dentro do target `AirShortcut`; T20 continua condicional.

**Gate T02:** `git diff --check` — PASS; `swift build --disable-sandbox
--product AirShortcut` — PASS. Nenhum comportamento ou teste foi alterado.
