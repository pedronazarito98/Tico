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
| T03 | ✅ | Inventário de isolamento e invariantes abaixo; commit pendente |
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

## T03 — auditoria de concorrência e callbacks

O inventário foi feito por busca de `@unchecked Sendable`, filas,
continuations, callbacks C/AppKit e `@MainActor`, seguido de leitura dos
owners. As invariantes também foram registradas nos comentários dos tipos
`@unchecked Sendable`; não houve ativação de Swift 6 estrito.

| Fronteira | Invariante/owner | Classificação | Tarefa proprietária |
|---|---|---|---|
| `Services/MultitouchFrameProvider.swift:8` + bridge C `AirShortcutMultitouchBridge.c:76-117` | O bridge pode chamar fora da main; `TrackpadGestureService` é owner do ciclo `start/stop` e o contexto retido só é liberado depois da parada. | ⚠️ segura sob ownership atual; uso direto concorrente não é suportado e deve permanecer isolado | T13/T16; revisão final T22 |
| `Services/ReplayFrameProvider.swift:34` | Callbacks são agendados na fila serial; `generation` invalida playback anterior; owner deve serializar start/stop. | ⚠️ segura sob ownership atual; acesso direto cross-thread permanece risco explícito | T15/T16; revisão final T22 |
| `Services/GestureProcessingWorker.swift:5` | Engine, calibração e flag de fases só são acessados pela fila serial interna. | ✅ isolada por fila; callback entrega somente valor `Sendable` | T13/T15 |
| `Services/GlobalEventTapService.swift:280` e callback C `:250-278` | `NSLock` protege resolução one-shot; instalação/stop usam run loop e semaphore; handlers são entregues na fila configurada. | ✅ lock/semáforo auditados; lifecycle continua owner do controller/coordenador | T13/T16 |
| `Services/TrackpadSessionRecorder.swift:6` | Todos os campos mutáveis de gravação ficam sob `NSLock`; `stop` entrega snapshot por valor e anonimiza device ID. | ✅ lock auditado e fronteira segura para callbacks | T15 |
| `Services/MacOSShortcutRunner.swift:114` | `NSLock` protege continuation, conclusão one-shot e timeout contra término/cancelamento simultâneos. | ✅ lock auditado; processo continua efeito de plataforma isolado | T14/T16 |
| `Services/ShellScriptRunner.swift:152` | Buffers de stdout/stderr e truncamento são protegidos por `NSLock` entre readability handlers e termination handler. | ✅ lock auditado; não registra payload fora do limite | T14/T16 |
| `Services/ShellScriptRunner.swift:192` | `NSLock` protege continuation, conclusão one-shot e timeout do processo. | ✅ lock auditado; cancelamento não pode resumir continuation duas vezes | T14/T16 |
| `Services/TrackpadGestureService.swift:469` | A referência weak só faz ponte para `MainActor`; callback agenda o processamento no actor e não muta estado diretamente. | ✅ bridge estreita; lifecycle e estado pertencem ao `@MainActor` da linha 22 | T13/T15 |

### Outras fronteiras sem `@unchecked Sendable`

- `TrackpadGestureService` e `AppController` são `@MainActor`
  (`TrackpadGestureService.swift:22` e `Support/AppController.swift:12`);
  callbacks C/AppKit atravessam `Task { @MainActor in ... }` antes de tocar
  estado publicado.
- `GlobalEventTapService` usa `deliveryQueue` para não executar o handler no
  callback do tap; `EventTapInstallation` cobre a corrida instalação/timeout.
- Continuations de `MacOSShortcutRunner`, `ShellScriptRunner` e
  `AppController.requestScriptApproval` são completadas por resolvers/owners
  one-shot. A revisão de T14/T16 deve preservar essa propriedade.
- O bridge C carrega `MultitouchSupport` dinamicamente e não publica memória de
  toque depois do callback; o owner Swift deve manter a vida do contexto até
  `stop`.

**Resultado T03:** não há fronteira classificada como bloqueio imediato para a
modernização incremental. As duas classes de provider dependem de ownership
serializado e ficam explicitamente marcadas para revisão nas tarefas de captura
e laboratório; isso não autoriza ativar strict concurrency global.

**Gate T03:** `git diff --check` — PASS. A primeira tentativa de build foi
`BLOCKED` pelo cache global do Clang (`Operation not permitted`); a repetição
com `CLANG_MODULE_CACHE_PATH=/private/tmp/tico-clang-module-cache` e
`SWIFT_MODULECACHE_PATH=/private/tmp/tico-swift-module-cache` passou com
`swift build --disable-sandbox --product AirShortcut`. Não houve teste novo nem
alteração comportamental.
