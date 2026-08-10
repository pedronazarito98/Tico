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
| T03 | ✅ | Inventário/invariantes `6ece334`; follow-ups de código/documentação `637f4af`, `1b19757`, `5c697b7`, `4d667c4`, `6bd6609` |
| T04 | ✅ | `490ed78`; `RuleEditingSessionTests` — 3 testes, 0 falhas; build do produto PASS |
| T05 | ✅ | `9e744fa`; `AdvancedPhasesTests` — 13 testes, 0 falhas; build do produto PASS |
| T06 | ✅ | `b08c993`; `RuleEditingSessionTests` — 3 testes, 0 falhas; build do produto PASS |
| T07 | ✅ | `28d96d4`; `RuleEditingSessionTests` — 3 testes, 0 falhas; build do produto PASS |
| T08 | ✅ | `89e3adc`; `RuleEditingSessionTests` — 3 testes, 0 falhas; build do produto PASS |
| T09 | ✅ | `69c02e9`, `7f0abec`, `5cbd0a5`; suíte completa — 114 testes, 0 falhas; revisão independente PASS |
| T10 | ✅ | `44fdcf6`; `ShortcutStoreTests` — 13 testes, 0 falhas; build do produto PASS |
| T11 | ✅ | `381f7ab`; `ShortcutStoreTests` — 15 testes, 0 falhas; `SecurityRegressionTests` — 8 testes, 0 falhas |
| T12 | ✅ | `10fffea`, `3062882`, `6f90a48`; suíte da fase — 117 testes, 0 falhas; build do produto PASS |
| T13 | ✅ | `7f97b31`, `6499b20`, `d64e975`; `CaptureCoordinatorTests` — 3 testes, 0 falhas |
| T14 | ✅ | `6f4131f`, `d64e975`; `AutomationAndProfilesTests` — 12 testes, 0 falhas |
| T15 | ✅ | `6f4131f`, `d64e975`; `TrackpadLaboratoryPhaseOneTests` — 9 testes, 0 falhas |
| T16 | ✅ | `6f4131f`, `d64e975`; suíte da fase — 122 testes, 0 falhas; revisão independente PASS |
| T17 | ✅ | `be8c9ed`; `AppCommandRouterTests` — 2 testes, 0 falhas |
| T18 | ✅ | `52fb062`; `ApplicationLifecycleServiceTests` — 1 teste, 0 falhas |
| T19 | ✅ | `be8c9ed`, `52fb062`; suíte da fase — 125 testes, 0 falhas |
| T20 | ✅ | análise do grafo + `swift package dump-package`; decisão documentada: não extrair |
| T21 | ✅ | documentação sincronizada em `outputs/arquitetura.md`, `CONTRIBUTING.md` e `AGENTS.md` aplicáveis |
| T22 | ✅ | gate canônico PASS, matriz ARCH-01–ARCH-10, UAT separado e handoff final |

## Gates e limites

As tabelas de gates de fase, rastreabilidade ARCH-01–ARCH-10, auditoria de
concorrência e UAT estão preenchidas com comandos, resultados reais e limites
separados por risco.

## T02 — mapa de dependências e ownership

**Arquivos alterados:** somente `design.md` e este relatório.

| Seam | Produtor | Consumidores | Efeitos | Owner observado |
|---|---|---|---|---|
| `RuleEditorView` | `Views/RulesView.swift:35-58` | `Views/ContentView.swift:168-189` → `RulesView` | closures de save/conflito/preset e captura; nenhum IO direto | `@State` local em `RuleEditorView.swift:27-32`; sessão explícita ainda inexistente |
| `ShortcutStore` | `App/AirShortcutApp.swift:17-24` | `ContentView.swift:4-5,168-223`; `RulesView.swift:4,35-190`; `ProfilesView.swift:4`; `GestureLibraryView.swift:4`; `MenuBarContentView.swift:5-6`; `Support/AppController.swift:33,67,86,164,448-450,578-581,625-627`; `ShortcutStoreTests.swift:18,26,32-35,44,61,78,86,101,109,129,138,162,168,188,192,200,237,242,257,259,282`; `TicoCompatibilityTests.swift:23,47,97`; `SecurityRegressionTests.swift:37,39,98,108,235`; `AutomationAndProfilesTests.swift:84,122,153`; `AdvancedPhasesTests.swift:432,460,469` | leitura/migração, JSON, backup, escrita atômica, import/export | `ObservableObject` publica coleções e coordena invariantes, mas ainda contém IO |
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
| `WeakTrackpadGestureServiceBox` em `Services/TrackpadGestureService.swift:466-473` | A referência weak pode zerar somente pelo ciclo de vida do serviço; o callback lê a referência e agenda processamento no `MainActor`, sem mutar estado diretamente. | ✅ bridge estreita; lifecycle e estado pertencem ao `@MainActor` da linha 22 | T13/T15 |
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
| `swift test --disable-sandbox` | PASS — 111 testes, 0 falhas, executado após os follow-ups com caches explícitos em `/private/tmp` |
| Avisos de ambiente | Cache SwiftPM/Clang global sem escrita; suíte repetida com caches em `/private/tmp` |
| Revisão estrutural fresh-eyes | PASS — follow-ups da fase, todas as 9 declarações `@unchecked Sendable` com comentário e entrada no inventário |
| Revisor independente | PASS final no HEAD `6bd6609` (`019fe78f-1003-78f0-b33c-e53dc869327f`); falhas iniciais e lacunas documentais corrigidas nos commits listados acima |
| Hardware/TCC/assinatura/notarização | NOT-RUN |

**Decisão de avanço:** a Fase 0 não alterou comportamento, não encontrou ciclo
de dependência que bloqueie a decomposição e deixou os riscos de provider
explicitamente atribuídos a T13/T15/T22. A Fase 1 pode começar.

## Fase 1 — decomposição do editor (T04–T09)

**Resultado de código:** concluído. A composição do editor agora mantém uma
única fonte de verdade em `RuleEditingSession`, enquanto os subcomponentes
recebem apenas bindings, valores e closures. A fachada pública de
`RuleEditorView` e o contrato de `RulesView` foram preservados.

### Ownership e fronteiras

- `RuleEditingSession.swift` concentra o rascunho, baseline salvo, modo de
  gravação, expansão de opções avançadas, validação de URL, presets, conflito,
  erro e transições de salvar/reverter. Não acessa disco, AppKit ou controller.
- `RuleTriggerEditorView.swift` compõe os tipos de gatilho e delega a
  configuração de trackpad para `TrackpadTriggerEditorView.swift`.
- `RuleEditorHeaderView.swift` e `RuleEditorFooterView.swift` mantêm o
  chrome e as ações do editor sem conhecer persistência.
- `RuleEditorView.swift` monta a tela, traduz eventos da sessão em closures
  externas e mantém somente o `@StateObject` da sessão.
- `RuleURLValidator.swift` é a fronteira pura compartilhada pela sessão e
  pelo editor de ação; a regra permanece HTTP/HTTPS como antes.

### Gates executados

| Gate | Resultado |
|---|---|
| `git diff --check` | PASS |
| `swift build --disable-sandbox --product AirShortcut` | PASS — caches de módulo em `/private/tmp/tico-clang-module-cache` e `/private/tmp/tico-swift-module-cache` |
| `swift test --disable-sandbox --filter RuleEditingSessionTests` | PASS — 3 testes, 0 falhas |
| `swift test --disable-sandbox --filter AdvancedPhasesTests` | PASS — 13 testes, 0 falhas |
| `swift test --disable-sandbox` | PASS — 114 testes, 0 falhas, após a correção final T09 |
| Revisão independente estática | PASS — `019fe7c2-0c2e-7481-8f4a-dd9b3d5ab8a5` |

As duas revisões intermediárias encontraram estado de URL duplicado/não
conectado e um parâmetro residual; ambos foram removidos nos commits
`7f0abec` e `5cbd0a5`. Não há `urlText` armazenado na sessão nem no
editor de ação, e não há helpers de gatilho transitórios remanescentes em
`RuleEditorView`.

### UAT e limites

A tentativa de UAT via Computer Use foi **NOT-RUN/BLOCKED**: o executável
compilado foi iniciado e um bundle temporário em `/private/tmp/Tico-UAT.app`
foi reconhecido como processo de menu bar, mas o canal nativo de automação
encerrou antes de retornar estado AX/screenshot. Portanto não há evidência
visual ou de interação contínua para declarar a UI aprovada.

Ainda requer validação manual no macOS: abrir Preferências/Regras, editar nome
e habilitação, alternar os cinco tipos de gatilho, expandir opções avançadas
de trackpad, abrir workflow e notas, cancelar/reverter, salvar, testar
conflito/preset, `⌘S`, foco/acessibilidade e light/dark mode. Trackpad físico,
TCC, sleep/wake físico, assinatura Developer ID e notarização permanecem
NOT-RUN.

**Decisão de avanço:** os gates de código, build e suíte estão verdes; a
limitação de UAT é registrada separadamente e não é convertida em PASS por
inspeção estática.

## T03 — follow-up após revisão independente

O revisor apontou uma corrida real em `ReplayFrameProvider`, inventário AppKit
incompleto e referências documentais imprecisas. O follow-up aplicou:

- `ReplayFrameProvider.swift:36-47,78-151`: `NSLock` protege `running` e
  `generation` tanto nos métodos públicos quanto no callback agendado;
  callbacks antigos continuam invalidados por generation.
- `AppController.swift:183-187`: o sink de `NSWorkspace` agenda a atualização
  no `MainActor` em vez de chamar diretamente o método isolado.
- `ReplayFrameProvider.swift:30-34`: contrato explicita que um callback já
  validado pode estar em voo após `stop()`; frames posteriores continuam
  invalidados por `generation`.
- `validation.md:95-131` e `design.md:106-114`: inventário inclui
  `ApplicationLauncher`, diferencia `Task` de `MainActor.assumeIsolated`,
  corrige o caminho do controller e lista consumidores com `file:line`.

**Gate do follow-up:** `git diff --check` — PASS; build com caches em
`/private/tmp` — PASS; `swift test --disable-sandbox --filter
TrackpadLaboratoryPhaseOneTests` — PASS, 9 testes/0 falhas; o gate completo
posterior também passou com 111 testes/0 falhas. Commits de código e
documentação estão listados na tabela T03. A revisão independente final
confirmou que todas as leituras/escritas de `running`/`generation` ficam sob
`stateLock`, que o callback em voo está documentado e que o inventário tem
referências `file:line` completas.

## Fase 2 — persistência e store (T10–T12)

**Resultado de código:** concluído. A persistência foi separada em duas
fronteiras internas, mantendo `ShortcutStore` como fachada observável para o
estado e as invariantes.

### Ownership e compatibilidade

- T10 moveu `ShortcutDocument`, `DecodedShortcutDocument`, versionamento,
  encode/decode, migração de array legado e validação de documento para
  `ShortcutDocumentCodec.swift`. A versão pública de compatibilidade continua
  em `ShortcutStore.currentDocumentVersion`, apontando para o codec.
- T11 introduziu `ShortcutRepository` e `FileShortcutRepository`. A
  implementação concentra `FileManager`, leitura limitada pela
  `DocumentSecurityPolicy`, criação de diretórios, escrita `.atomic`,
  importação/exportação e backups `vN.backup.json`.
- T12 manteve os arrays publicados, CRUD, conflitos, sincronização de
  templates, merge e rollback no store. O store não usa mais
  `JSONEncoder`, `JSONDecoder`, `FileHandle` ou `Data(contentsOf:)`; a
  inicialização por `repository:` torna a fronteira substituível sem
  alterar o inicializador legado por `fileURL:`.

### Gates executados

| Gate | Resultado |
|---|---|
| `git diff --check` | PASS |
| `swift build --disable-sandbox --product AirShortcut` | PASS — caches de módulo em `/private/tmp/tico-clang-module-cache` e `/private/tmp/tico-swift-module-cache` |
| `swift test --disable-sandbox --filter ShortcutStoreTests` | PASS — 15 testes, 0 falhas |
| `swift test --disable-sandbox --filter SecurityRegressionTests` | PASS — 8 testes, 0 falhas |
| `swift test --disable-sandbox` | PASS — 117 testes, 0 falhas |

Durante a primeira execução de T11, um erro de implementação no nome do
backup foi detectado pelo teste de migração; a correção foi aplicada antes do
commit e os gates foram repetidos. Os avisos de cache SwiftPM global e os
cinco `AGENTS.md` tratados como arquivos não processados continuam sendo
limitações do ambiente, sem falha de compilação.

### Segurança e rollback

Round-trip de CRUD, documento vazio, versão legada 0, migrações de versões 1/2,
backup versionado, importação replace/merge, rejeição de documentos malformados
e limite de tamanho foram exercitados pela suíte existente. Falhas de escrita
continuam restaurando a coleção anterior; leitura/importação falha antes de
alterar o estado publicado.

**Decisão de avanço:** build, testes direcionados e suíte completa estão
verdes. A revisão independente final retornou PASS no
`019fe7e7-1001-7e61-ae87-256777379a6b`; nenhuma evidência de IO foi
confundida com UAT de hardware.

### Follow-ups da revisão independente

1. `3062882` corrigiu a publicação antecipada de templates: a coleção
   sincronizada agora é calculada em valor e só substitui o estado publicado
   após `repository.write` retornar sucesso. O teste
   `testFailedWriteDoesNotPublishEmbeddedTemplate` cobre a regressão.
2. `6f90a48` corrigiu a publicação antecipada em `load()`: seed, leitura e
   migração capturam um snapshot de todas as coleções e restauram o estado em
   qualquer falha de leitura, backup ou escrita. O teste
   `testFailedSeedDoesNotPublishExamples` cobre o caminho de falha.
3. O contrato do repositório passou a documentar a obrigação de escrita
   atômica para implementações, e a criação do documento foi movida para o
   codec. O revisor classificou o acoplamento restante ao tipo de documento
   como P2 não bloqueante e não encontrou P1.

## Fase 3 — coordenação de aplicação (T13–T16)

**Resultado de código:** concluído. O `AppController` mantém a fachada e o
composition root, enquanto a captura, a automação e o laboratório têm owners
isolados e `@MainActor`. Projeções publicadas continuam compatíveis com as
views existentes.

### Ownership e invariantes

- `CaptureCoordinator` possui o tap global, o ciclo do `TrackpadGestureService`
  e as gerações de captura/observação. `isStopping` bloqueia restart enquanto
  um tap anterior ainda reporta encerramento; callbacks de eventos e estado
  são descartados quando pertencem a uma geração antiga.
- `AutomationCoordinator` possui sequência, tarefas de workflow, sessões
  contínuas e a aprovação de scripts. Cada aprovação guarda `ruleID` e
  `executionID`; cancelar o workflow resolve a `CheckedContinuation` com
  recusa e não deixa a UI presa em `pendingScriptApproval`.
- `LaboratoryCoordinator` possui gravação, replay, snapshot e calibração como
  projeções do serviço de trackpad. `TrackpadGestureService` invalida replay
  anterior por geração antes e depois do processamento assíncrono; replay
  continua publicando laboratório e nunca chama a pipeline de ações reais.
- `AppController` apenas compõe dependências, encaminha eventos semânticos,
  conserva o catálogo de aplicações e expõe a API compatível usada por
  `ContentView` e `MenuBarContentView`.

### Gates executados

| Gate | Resultado |
|---|---|
| `git diff --check` | PASS |
| `swift build --disable-sandbox --product AirShortcut` | PASS — caches de módulo em `/private/tmp/tico-clang-module-cache` e `/private/tmp/tico-swift-module-cache` |
| `swift test --disable-sandbox --filter CaptureCoordinatorTests` | PASS — 3 testes, 0 falhas |
| `swift test --disable-sandbox --filter AutomationAndProfilesTests` | PASS — 12 testes, 0 falhas |
| `swift test --disable-sandbox --filter TrackpadLaboratoryPhaseOneTests` | PASS — 9 testes, 0 falhas |
| `swift test --disable-sandbox` | PASS — 122 testes, 0 falhas |
| Revisão independente pós-correção | PASS — `019fe9da-70c8-7550-bc1c-afa371cdc76c` |

A revisão intermediária encontrou três falhas P1: restart reportado como
sucesso durante stop atrasado, aprovação pendente sem resolução ao cancelar e
publicação tardia de replay. `6499b20` e `d64e975` corrigiram os três pontos;
os testes direcionados e a suíte completa foram repetidos após a correção.

### UAT e limites

UAT contínuo de captura, automação e laboratório permanece **NOT-RUN**; a
tentativa anterior de UAT nativo do editor foi **BLOCKED** porque o processo
de menu bar perdeu o canal de automação antes de retornar estado AX/screenshot.
Os testes de laboratório usam provider determinístico e comprovam ausência de
execução de regras no replay, mas não substituem interação física.

Trackpad físico, TCC em máquina real, sleep/wake físico, assinatura Developer
ID e notarização permanecem **NOT-RUN**.

## Fase 4 — shell macOS e avaliação de módulo (T17–T20)

**Resultado de código:** concluído. Os comandos de menu/atalho agora passam
por `AppCommandRouter`, com envelopes consumidos uma vez e uma ponte de
compatibilidade que ainda traduz as notificações `AirShortcut.*`. O ciclo de
vida AppKit está atrás de `ApplicationLifecycleControlling` e
`ApplicationLifecycleService`; `MenuBarContentView` não importa nem referencia
AppKit diretamente.

### T20 — decisão de não extrair `AirShortcutCore`

A análise do checkout não atende ao critério de uma extração segura nesta
fase:

- `Package.swift` possui um único target executável Swift (`AirShortcut`) e o
  target C `AirShortcutMultitouchBridge`; o teste depende do executável.
- `Models` usa apenas `Foundation`, mas os tipos são consumidos diretamente
  por `Stores`, `Services`, coordenadores e views. Uma separação imediata
  exigiria tornar uma malha ampla de tipos/internal APIs pública ou mover
  também serviços que dependem de AppKit, ApplicationServices, CoreGraphics,
  IOKit e do bridge C.
- `ShortcutDocumentCodec` e alguns engines são puros, mas não formam um
  conjunto de consumidores independentes suficiente para justificar um target
  novo sem duplicação, migração de visibilidade ou acoplamento adicional.

Resultado válido conforme a spec: **não extrair**. `Package.swift` permanece
inalterado; não foi adicionada dependência nem framework arquitetural.

### Gates executados

| Gate | Resultado |
|---|---|
| `git diff --check` | PASS |
| `swift build --disable-sandbox --product AirShortcut` | PASS — caches de módulo em `/private/tmp/tico-clang-module-cache` e `/private/tmp/tico-swift-module-cache` |
| `swift test --disable-sandbox --filter AppCommandRouterTests` | PASS — 2 testes, 0 falhas |
| `swift test --disable-sandbox --filter ApplicationLifecycleServiceTests` | PASS — 1 teste, 0 falhas |
| `swift test --disable-sandbox` | PASS — 125 testes, 0 falhas |
| `swift package dump-package` | PASS — targets `AirShortcutMultitouchBridge`, `AirShortcut` e `AirShortcutTests` |
| Revisão independente da Fase 4 | PASS — `019febaf-25da-7db1-b6d1-9863934a871f`, HEAD `d2395e4` |
| UAT menus/atalhos/janelas | NOT-RUN — sem prova de interação contínua do shell nativo |

O teste de ciclo de vida usa um controlador injetado e não executa término ou
abertura real de janela. A validação manual de menu, atalhos, reabertura da
janela principal e encerramento continua separada dos gates automatizados.

## T21 — sincronização de arquitetura e regras

A documentação foi alinhada ao checkout efetivo:

- `outputs/arquitetura.md` descreve os owners do editor, persistência,
  coordenadores e shell, além da decisão de manter um target SwiftPM único.
- `CONTRIBUTING.md` registra branch-by-abstraction, fronteiras de codec/
  repository, comandos tipados, isolamento AppKit e o critério para uma futura
  avaliação de módulo.
- `AGENTS.md` e `Sources/AirShortcut/AGENTS.md` deixam explícito que Views não
  referenciam AppKit e que `Support` só abriga coordenação quando o owner está
  claro. As regras especializadas de Views, Stores, Services e Tests continuam
  compatíveis e não foram substituídas.

**Gate T21:** `git diff --check` — PASS. Nenhuma documentação afirma UAT,
hardware, TCC, assinatura ou notarização como concluídos.

## T22 — fechamento e limites finais

### Gates finais executados

| Evidência | Resultado |
|---|---|
| `git diff --check` | PASS antes do fechamento documental |
| `swift build --disable-sandbox --product AirShortcut` | PASS — produto AirShortcut; caches de módulo em `/private/tmp/tico-clang-module-cache` e `/private/tmp/tico-swift-module-cache` |
| `swift test --disable-sandbox` | PASS — 125 testes, 0 falhas |
| `AIRSHORTCUT_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package` | PASS — 125 testes, 0 falhas; 8 regressões de segurança; pacote ad hoc `dist/Tico.zip` verificado |
| `swift package dump-package` | PASS — `AirShortcutMultitouchBridge`, `AirShortcut` e `AirShortcutTests` |
| Arquivos não rastreados após o gate | nenhum |
| Revisão independente final | PASS — `019febaf-25da-7db1-b6d1-9863934a871f`; revisão read-only do HEAD final |

O `ci_verify.sh` classificou explicitamente trackpad físico e notarização como
não exercitados. Os avisos repetidos do SwiftPM sobre os cinco `AGENTS.md`
especializados são limitações de descoberta de arquivos do target, não falhas
de compilação ou teste.

### Matriz ARCH-01–ARCH-10

| Requisito | Resultado | Evidência principal |
|---|---|---|
| ARCH-01 | PASS | Fachadas compatíveis, `TicoCompatibilityTests` — 4/0, suite 125/0, formatos/chaves preservados |
| ARCH-02 | PASS | `AGENTS.md` raiz e regras especializadas aplicáveis, sincronizados em T21 |
| ARCH-03 | PASS | `RuleEditingSession`, subviews do editor e `RuleEditingSessionTests` — 3/0 |
| ARCH-04 | PASS | codec/repository/store; `ShortcutStoreTests` — 15/0 e `SecurityRegressionTests` — 8/0 |
| ARCH-05 | PASS | três coordenadores `@MainActor`, fachada `AppController`, suites de coordenação/laboratório |
| ARCH-06 | PASS | `AppCommandRouter`, `ApplicationLifecycleService`, testes 2/0 e 1/0; UAT nativo NOT-RUN |
| ARCH-07 | PASS | T20 “não extrair”, análise de imports/grafo e `dump-package`; `Package.swift` sem dependência nova |
| ARCH-08 | PASS | inventário T03, gerações/continuations, testes de captura/automação/replay e revisão de fase |
| ARCH-09 | PASS | gates rápidos, gates de fase, gate canônico e limites separados neste relatório |
| ARCH-10 | PASS | `outputs/arquitetura.md`, `CONTRIBUTING.md`, `AGENTS.md`, spec/context/design sincronizados |

### UAT e gates separados

| Superfície | Resultado |
|---|---|
| Editor nativo contínuo | BLOCKED — canal de automação nativa encerrou antes de AX/screenshot; sem PASS visual por inspeção |
| Captura/automação/laboratório em interação contínua | NOT-RUN |
| Menus, atalhos, reabertura e encerramento do shell | NOT-RUN |
| Trackpad físico | NOT-RUN |
| TCC real / Monitoramento de Entrada | NOT-RUN |
| Sleep/wake físico | NOT-RUN — simulação determinística automatizada PASS, não é prova física |
| Assinatura Developer ID | NOT-RUN — pacote final automatizado é ad hoc |
| Notarização | NOT-RUN |

Uma revisão independente final confirmou o HEAD e encontrou apenas duas frases
stale no handoff; elas foram removidas no commit documental seguinte. Nenhum
finding de código, dependência acidental ou regressão adicional foi reportado.
