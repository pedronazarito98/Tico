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
| T01 | ✅ | Baseline acima; `8af837c` |
| T02 | ✅ | Mapa de seams em `design.md`; `2b17908` |
| T03 | ✅ | Inventário/invariantes `6ece334`; follow-up `637f4af` |
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
| `ShortcutStore` | `App/AirShortcutApp.swift:17-24` | `ContentView.swift:4-5,168-223`; `RulesView.swift:4,35-190`; `ProfilesView.swift:4`; `GestureLibraryView.swift:4`; `MenuBarContentView.swift:5-6`; `Support/AppController.swift:33,67,86,164,448-450,578-581,625-627`; `ShortcutStoreTests.swift:18,26,32-35,44,61,78,86,101,109,129,138,162,188,192,200,237,242,257,259,282`; `TicoCompatibilityTests.swift:23,47,97`; `SecurityRegressionTests.swift:37,39,98,108,235`; `AutomationAndProfilesTests.swift:84,122,153`; `AdvancedPhasesTests.swift:432,460,469` | leitura/migração, JSON, backup, escrita atômica, import/export | `ObservableObject` publica coleções e coordena invariantes, mas ainda contém IO |
| `AppController` | `App/AirShortcutApp.swift:29-38` | `ContentView.swift:4,35-41,107-243,287-333`; `MenuBarContentView.swift:5`; `SecurityRegressionTests.swift:234-259` | captura global/trackpad, laboratório, automação, catálogo e tarefas | `@MainActor` em `Support/AppController.swift:12`; fachada temporária compatível |

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
| `Services/ReplayFrameProvider.swift:34` | Callbacks são agendados na fila serial; `stateLock` protege `running`/`generation` entre start/stop e a fila; `generation` invalida playback anterior. | ✅ estado compartilhado protegido; callback ainda é efeito do owner do laboratório | T15/T16; revisão final T22 |
| `Services/GestureProcessingWorker.swift:5` | Engine, calibração e flag de fases só são acessados pela fila serial interna. | ✅ isolada por fila; callback entrega somente valor `Sendable` | T13/T15 |
| `Services/GlobalEventTapService.swift:280` e callback C `:250-278` | `NSLock` protege resolução one-shot; instalação/stop usam run loop e semaphore; handlers são entregues na fila configurada. | ✅ lock/semáforo auditados; lifecycle continua owner do controller/coordenador | T13/T16 |
| `Services/TrackpadSessionRecorder.swift:6` | Todos os campos mutáveis de gravação ficam sob `NSLock`; `stop` entrega snapshot por valor e anonimiza device ID. | ✅ lock auditado e fronteira segura para callbacks | T15 |
| `Services/MacOSShortcutRunner.swift:114` | `NSLock` protege continuation, conclusão one-shot e timeout contra término/cancelamento simultâneos. | ✅ lock auditado; processo continua efeito de plataforma isolado | T14/T16 |
| `Services/ShellScriptRunner.swift:152` | Buffers de stdout/stderr e truncamento são protegidos por `NSLock` entre readability handlers e termination handler. | ✅ lock auditado; não registra payload fora do limite | T14/T16 |
| `Services/ShellScriptRunner.swift:192` | `NSLock` protege continuation, conclusão one-shot e timeout do processo. | ✅ lock auditado; cancelamento não pode resumir continuation duas vezes | T14/T16 |
| `Services/TrackpadGestureService.swift:469` | A referência weak pode zerar somente pelo ciclo de vida do serviço; o callback lê a referência e agenda processamento no `MainActor`, sem mutar estado diretamente. | ✅ bridge estreita; lifecycle e estado pertencem ao `@MainActor` da linha 22 | T13/T15 |
| `Services/ApplicationLauncher.swift:27-56` | Completion de `NSWorkspace.openApplication` resume a continuation uma vez e devolve somente erro tipado ao chamador assíncrono. | ✅ callback de plataforma isolado pela porta `ApplicationLaunching`; não toca UI diretamente | T14/T16 |

### Outras fronteiras sem `@unchecked Sendable`

- `TrackpadGestureService` e `AppController` são `@MainActor`
  (`TrackpadGestureService.swift:22` e `Support/AppController.swift:12`). O
  callback do provider e o monitor global usam `Task { @MainActor in ... }`;
  o monitor local usa `MainActor.assumeIsolated` porque é instalado pelo
  serviço main-actor e o callback é tratado como síncrono nesse contrato.
- O sink de notificações `NSWorkspace` do controller agenda
  `refreshApplicationCatalog()` em `Task { @MainActor in ... }`, evitando uma
  chamada direta de método isolado a partir do callback do publisher.
- Os publishers de sleep/wake em `TrackpadGestureService.swift:79-87`
  também atravessam `Task { @MainActor in ... }` antes de alterar o serviço.
- `GlobalEventTapService` usa `deliveryQueue` para não executar o handler no
  callback do tap; `EventTapInstallation` cobre a corrida instalação/timeout.
- Continuations de `MacOSShortcutRunner`, `ShellScriptRunner` e
  `AppController.requestScriptApproval` são completadas por resolvers/owners
  one-shot. A revisão de T14/T16 deve preservar essa propriedade.
- O bridge C carrega `MultitouchSupport` dinamicamente e não publica memória de
  toque depois do callback; o owner Swift deve manter a vida do contexto até
  `stop`.

**Resultado T03:** a revisão independente encontrou e o follow-up corrigiu a
race de estado do provider de replay, além de completar callbacks AppKit e
referências `file:line`. Não há bloqueio imediato para a modernização
incremental; a auditoria não autoriza ativar strict concurrency global.

### Remediação do revisor independente

| Achado | Correção |
|---|---|
| `ReplayFrameProvider` compartilhava `isRunning`/`generation` sem isolamento | `stateLock` agora protege leitura, escrita e validação do generation; o callback da fila não acessa os campos sem lock. |
| `ApplicationLauncher` e sink `NSWorkspace` ausentes | Inventário inclui `ApplicationLauncher.swift:27-56`; `AppController` agenda refresh no `MainActor`. |
| Documentação dizia que todo callback usava `Task` e chamava weak box imutável | Texto distingue `Task` de `MainActor.assumeIsolated` e descreve corretamente o `weak var`. |
| Caminho inválido e consumidores sem `file:line` | `design.md` usa `Support/AppController.swift`; tabela T02 lista consumidores e linhas concretas. |

**Gate T03:** `git diff --check` — PASS. A primeira tentativa de build foi
`BLOCKED` pelo cache global do Clang (`Operation not permitted`); a repetição
com `CLANG_MODULE_CACHE_PATH=/private/tmp/tico-clang-module-cache` e
`SWIFT_MODULECACHE_PATH=/private/tmp/tico-swift-module-cache` passou com
`swift build --disable-sandbox --product AirShortcut`. Não houve teste novo nem
alteração comportamental.

## Fechamento da Fase 0

| Gate | Resultado |
|---|---|
| `git diff --check` | PASS |
| `swift test --disable-sandbox` | PASS — 111 testes, 0 falhas |
| Avisos de ambiente | Cache SwiftPM/Clang global sem escrita; suíte repetida com caches em `/private/tmp` |
| Revisão estrutural fresh-eyes | PASS — três commits da fase, todas as 9 declarações `@unchecked Sendable` com comentário e entrada no inventário |
| Revisor independente | FAIL inicial; achados P1/P2 corrigidos em `637f4af`; re-review worker não retornou, com fresh-eyes read-only local PASS |
| Hardware/TCC/assinatura/notarização | NOT-RUN |

**Decisão de avanço:** a Fase 0 não alterou comportamento, não encontrou ciclo
de dependência que bloqueie a decomposição e deixou os riscos de provider
explicitamente atribuídos a T13/T15/T22. A Fase 1 pode começar.

## T03 — follow-up após revisão independente

O revisor apontou uma corrida real em `ReplayFrameProvider`, inventário AppKit
incompleto e referências documentais imprecisas. O follow-up aplicou:

- `ReplayFrameProvider.swift:36-47,78-151`: `NSLock` protege `running` e
  `generation` tanto nos métodos públicos quanto no callback agendado;
  callbacks antigos continuam invalidados por generation.
- `AppController.swift:183-187`: o sink de `NSWorkspace` agenda a atualização
  no `MainActor` em vez de chamar diretamente o método isolado.
- `validation.md:95-131` e `design.md:106-114`: inventário inclui
  `ApplicationLauncher`, diferencia `Task` de `MainActor.assumeIsolated`,
  corrige o caminho do controller e lista consumidores com `file:line`.

**Gate do follow-up:** `git diff --check` — PASS; build com caches em
`/private/tmp` — PASS; `swift test --disable-sandbox --filter
TrackpadLaboratoryPhaseOneTests` — PASS, 9 testes/0 falhas. Commit do follow-up
é `637f4af`. A re-review local confirmou que todas as leituras/escritas de
`running`/`generation` ficam sob `stateLock`; o worker independente não
retornou um segundo veredito nesta sessão.
