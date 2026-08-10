# Design: modernização arquitetural incremental

## Opções consideradas

### A. Fronteiras internas primeiro, módulos depois — escolhida

Extrair estado, componentes, codecs, repositórios e coordenadores dentro do target atual. Manter fachadas compatíveis e só então avaliar um target SwiftPM interno.

**Vantagens:** diffs menores, rollback simples, testes existentes continuam úteis e o risco de ciclos entre módulos aparece antes da mudança de `Package.swift`.  
**Custo:** durante a transição, fachadas antigas e novas estruturas coexistirão.

### B. Dividir imediatamente em vários targets SwiftPM — rejeitada agora

Criaria limites fortes cedo, mas obrigaria a resolver simultaneamente acesso `internal`, recursos, dependências de SwiftUI/AppKit e ciclos ainda escondidos.

### C. Apenas mover arquivos para novas pastas — insuficiente

Melhoraria navegação, mas não separaria estado, efeitos e responsabilidades. Arquivos grandes continuariam concentradores em outro endereço.

## Arquitetura alvo

```text
SwiftUI Views
    │ valores, bindings e ações
    ▼
Estado de feature / coordenadores de aplicação
    │ comandos e resultados tipados
    ▼
Domínio puro ───────────────► Portas de persistência/plataforma
                                  │
                                  ▼
                         Arquivo, AppKit, eventos e bridge C
```

O fluxo de dependência aponta para dentro: domínio não conhece SwiftUI, AppKit, arquivos ou bridge C. Views não persistem e não controlam serviços diretamente. O `AppController` permanece temporariamente como composition root/fachada, mas deixa de implementar todos os fluxos.

## Componentes propostos

### 1. Editor de regras

- `RuleEditingSession`: estado de rascunho e transições válidas da edição.
- `RuleTriggerEditorView`: composição do tipo de gatilho.
- `TrackpadTriggerEditorView`: configuração e gravação de gesto.
- `RuleEditorHeaderView` e `RuleEditorFooterView`: chrome e ações explícitas.
- `RuleEditorView`: monta as partes e traduz a sessão em evento de salvar/cancelar.

A sessão não acessa disco nem AppKit. Subviews recebem apenas os valores, bindings e ações necessários.

### 2. Persistência de regras

- `ShortcutDocumentCodec`: codificação/decodificação e versões do documento.
- `ShortcutRepository`: porta de leitura e escrita.
- `FileShortcutRepository`: implementação com escrita atômica e política de segurança existente.
- `ShortcutStore`: estado publicado, invariantes de coleção e fachada compatível.

Migração, importação e exportação devem produzir resultados tipados. Falhas não podem destruir o último estado válido.

### 3. Coordenação de aplicação

- `CaptureCoordinator`: início, cancelamento e resultado da captura.
- `AutomationCoordinator`: ativação/desativação e execução contínua.
- `LaboratoryCoordinator`: gravação, replay e estado do laboratório.
- `AppController`: cria dependências, expõe projeções para a UI e mantém APIs antigas até seus consumidores migrarem.

Cada coordenador explicita isolamento (`@MainActor`, actor ou fila encapsulada) e não recebe a árvore inteira de estado se uma projeção menor bastar.

### 4. Shell macOS

- `AppCommandRouter`: ações tipadas para criar regra, abrir laboratório e demais comandos internos.
- `ApplicationLifecycleService`: operações estreitas que realmente precisam de `NSApplication`/AppKit.
- Views e menus usam ações do roteador; uma ponte temporária pode traduzir notificações legadas durante a migração.

### 5. Módulo interno condicional

Após as fronteiras anteriores, T20 avalia mover modelos e lógica pura para `AirShortcutCore`. O executável dependerá desse target por `.target(name:)`. A extração será cancelada se exigir levar SwiftUI/AppKit, criar ciclos ou duplicar tipos.

## Propriedade e fluxo de estado

- Objetos de longa duração são criados no composition root com `@StateObject`.
- Views filhas observam com `@ObservedObject` ou recebem projeções e closures.
- Estado efêmero de UI permanece em `@State`; preferências simples podem usar `@AppStorage`; estado por janela usa `@SceneStorage` quando aplicável.
- Não criar duas fontes de verdade para o mesmo rascunho, captura ou coleção de regras.
- Migração para Observation (`@Observable`) fica fora desta iniciativa.

## Reuso obrigatório

- Preservar `RuleConflictAnalyzer`, engines de gesto, protocolos de eventos e políticas de segurança existentes.
- Manter injeção já presente em serviços e stores; não introduzir um container genérico.
- Reutilizar `WorkflowEditorView` e `SequenceEditorView` como componentes dedicados.
- Manter scripts canônicos de build, testes e empacotamento.

## Compatibilidade e migração

Cada extração segue branch-by-abstraction:

1. criar a nova fronteira;
2. cobrir o comportamento com a suíte existente;
3. adaptar a fachada atual para delegar;
4. migrar consumidores;
5. remover apenas código comprovadamente morto.

Formatos persistidos, bundle, preferências e nomenclatura técnica não mudam. Qualquer migração de dados futura precisa de decisão e plano próprios.

## Riscos

| Risco | Evidência atual | Mitigação |
|---|---|---|
| Estado duplicado no editor | `Sources/AirShortcut/Views/RuleEditorView.swift` concentra rascunho, gravação e conflito | Criar uma sessão única antes de extrair subviews |
| Regressão de arquivo/migração | `Sources/AirShortcut/Stores/ShortcutStore.swift` combina coleção e IO | Extrair codec/repositório mantendo fachada e testes de store |
| Ciclo entre coordenadores | `Sources/AirShortcut/Support/AppController.swift` conhece stores e vários serviços | Definir entradas/saídas pequenas e composition root único |
| Comando recebido mais de uma vez | `ContentView` e `Commands` usam notificações globais | Ponte temporária com ownership e remoção explícitos |
| Corrida em callbacks | Serviços contêm fronteiras `@unchecked Sendable` | Inventário em T03 e isolamento documentado por tarefa |
| Módulo prematuro | Um único target Swift facilita acessos `internal` implícitos | T20 é condicional e vem depois das extrações |
| “Build verde” usado como prova física | Captura depende de hardware/TCC | Separar automação, UAT e gate de hardware |

## Regras de alteração

- Uma tarefa, uma responsabilidade principal e um diff revisável.
- Não misturar redesign visual com refatoração estrutural.
- Não mover vários subsistemas no mesmo commit planejado.
- Não criar abstração genérica antes de existirem pelo menos dois consumidores reais.
- Commits são apenas um plano de execução e exigem autorização explícita do usuário.

## Evidência do checkout — T02 (2026-08-09)

O mapa abaixo foi derivado do checkout após o baseline `8af837c`; ele registra
produtores, consumidores, efeitos e ownership observados, sem inferir
dependências que não aparecem no código.

### `RuleEditorView`

- **Produtor/compositor:** `Sources/AirShortcut/Views/RulesView.swift:35-58`
  cria a view quando há uma regra selecionada e fornece valores, bindings
  indiretos e closures estreitas.
- **Fonte dos valores:** `Sources/AirShortcut/Views/ContentView.swift:168-189`
  projeta estado de `ShortcutStore` e `AppController`; a view não recebe os
  objetos completos.
- **Efeitos:** `onSave` e `onReplaceConflicts` retornam para
  `RulesView` (`:175-180`), que delega ao store; gravação de gatilho usa
  `onStartRecording`/`onStopRecording` (`:50-51`), fornecidos pelo controller.
- **Ownership atual:** o rascunho e o estado efêmero vivem em `RuleEditorView`
  (`RuleEditorView.swift:27-32`); não há `RuleEditingSession` no checkout atual.
  T04 é a primeira tarefa autorizada a mover esse ownership para uma sessão
  explícita.
- **Fronteiras ausentes:** o arquivo não importa AppKit nem acessa arquivo; a
  persistência chega somente por closures. A decomposição pode permanecer
  dentro do target atual sem alterar o contrato de `RulesView`.

### `ShortcutStore`

- **Produtor/composition root:** `Sources/AirShortcut/App/AirShortcutApp.swift:17-24`
  cria uma única instância de longa duração com `@StateObject`.
- **Consumidores:** `ContentView.swift:4-5,168-223`,
  `RulesView.swift:4,107-190`, `ProfilesView.swift:4`,
  `GestureLibraryView.swift:4`, `MenuBarContentView.swift:5-6` e
  `Support/AppController.swift:33,67,86,164,448-450,578-581,625-627`.
  Testes de persistência/compatibilidade instanciam o store com `fileURL`
  temporário, incluindo `ShortcutStoreTests.swift:18-282` e a leitura da
  versão em `ShortcutStoreTests.swift:168`.
- **Efeitos:** leitura, migração e carga inicial em
  `ShortcutStore.swift:78-117`; CRUD e rollback em `:119-345`; importação e
  exportação em `:347-413`; escrita atômica em `:450-464`. A implementação
  usa `DocumentSecurityPolicy`, `FileManager`, `RuleConflictAnalyzer` e
  `JSONEncoder/Decoder` diretamente.
- **Ownership atual:** o store publica coleções e invariantes (`:29-44`), mas
  também possui codec, migração, backup, política de path e IO. T10/T11
  extraem essas fronteiras mantendo a fachada e os inicializadores injetáveis.

### `AppController`

- **Produtor/composition root:** `AirShortcutApp.swift:29-38` constrói o
  controller com store, settings, logs, permissões e stores de laboratório.
- **Consumidores:** `ContentView.swift:4,35-41,107-243,287-333` e
  `MenuBarContentView.swift:5` observam projeções e chamam métodos públicos;
  `SecurityRegressionTests.swift:234-259` usa o inicializador injetável.
- **Efeitos/serviços possuídos:** captura global, captura de trackpad,
  workflows, contexto, catálogo de apps/Atalhos, permissões e laboratório
  (`AppController.swift:42-65`). As publicações de laboratório são ligadas
  pelos `Combine` sinks de `:109-186`.
- **Ownership atual:** o controller é `@MainActor` (`:12`) e mantém estado de
  tela, tarefas de sequência/workflow e resolução de aprovação. T13/T14/T15
  devem extrair fluxos por capacidade; T16 preserva este owner como fachada e
  composition root até todos os consumidores migrarem.

### APIs que permanecem compatíveis durante a modernização

1. `RuleEditorView` continua recebendo `ShortcutRule` e os valores/closures
   atuais de `RulesView`; nenhuma assinatura externa é removida em T04–T09.
2. `ShortcutStore` mantém `fileURL`, `defaultFileURL`, versionamento 6,
   CRUD, conflitos, import/export, seed, migração e erros
   `ShortcutStoreError`; formatos, path `Application Support/AirShortcut` e
   chaves técnicas não mudam.
3. `AppController` mantém o inicializador injetável, propriedades publicadas e
   métodos chamados por `ContentView`/`MenuBarContentView`, incluindo
   `startCapture`, `stopCapture`, `startTrackpadObservation`, gravação e
   replay.

O mapa não encontrou dependência que justifique alterar `Package.swift` nesta
   etapa; a avaliação condicional de um target `AirShortcutCore` permanece em
   T20.

## Atualização pós-T09 — editor

O snapshot acima preserva a evidência histórica do T02. Após T04–T09, o
ownership do editor foi movido para
`Sources/AirShortcut/Views/Components/Rules/RuleEditingSession.swift`,
observável no `@StateObject` de `RuleEditorView`. A view principal agora é
composição e tradução de eventos; `RuleTriggerEditorView`,
`TrackpadTriggerEditorView`, `RuleEditorHeaderView` e
`RuleEditorFooterView` recebem somente bindings, valores e ações estreitas.

`RuleEditingSession` não conhece persistência, AppKit ou
`AppController`. A validação pura de URL foi compartilhada em
`Sources/AirShortcut/Support/RuleURLValidator.swift`. A assinatura pública de
`RuleEditorView` e os closures de `RulesView` permanecem compatíveis.

## Atualização pós-T12 — persistência

Após T10–T12, `ShortcutStore` continua sendo a fachada observável compatível
para estado, CRUD, conflitos, importação/exportação e invariantes de coleção,
mas não contém mais `JSONEncoder`, `JSONDecoder`, leitura de bytes ou
escrita atômica.

- `ShortcutDocumentCodec.swift` é dono do documento Codable, da versão 6,
  da decodificação legada (array de versão 0), dos defaults de versões antigas
  e da validação de limites antes de publicar o resultado.
- `ShortcutRepository.swift` define a porta injetável; `FileShortcutRepository`
  concentra `FileManager`, leitura limitada pela `DocumentSecurityPolicy`,
  encode/decode por codec, criação de diretório, escrita `.atomic` e backup
  versionado.
- `ShortcutStore(repository:seedExamples:now:)` preserva a injeção de relógio
  e path por meio do repositório; o inicializador legado com `fileURL` continua
  disponível e cria a implementação de arquivo padrão.

O repositório retorna o payload original junto do documento decodificado para
que a migração gere backup antes da sobrescrita. Falhas de gravação continuam
restaurando as coleções anteriores no store; falhas de leitura/importação
ocorrem antes da mutação publicada.

## Atualização pós-T16 — coordenação da aplicação

Após T13–T16, a coordenação foi separada por capacidade sem remover a fachada
compatível de `AppController`:

- `CaptureCoordinator` é o owner `@MainActor` do tap global e da observação de
  trackpad. Gerações independentes invalidam callbacks de eventos, estado e
  observação; um stop atrasado fica explícito em `isStopping` e impede um
  segundo start até o tap anterior se assentar.
- `AutomationCoordinator` é o owner `@MainActor` de sequência, workflows,
  sessões contínuas e aprovação de scripts. Uma aprovação é vinculada ao
  workflow por `ruleID`/`executionID`, permitindo cancelamento idempotente sem
  deixar uma `CheckedContinuation` pendente.
- `LaboratoryCoordinator` concentra gravação/replay e publica apenas as
  projeções necessárias. O replay do serviço usa generation para descartar
  resultado tardio depois de cancelamento e não atravessa o handler de regras.
- `AppController` constrói esses coordenadores, encaminha eventos semânticos e
  conserva projeções e métodos legados até que os consumidores sejam migrados.

Todos os três coordenadores são isolados na main actor porque possuem estado
observável e fazem a ponte com ações de UI. Os efeitos de plataforma continuam
atrás dos serviços/protocolos existentes; não foi introduzido container global,
singleton de aplicação ou migração ampla para Observation.

## Atualização pós-T20 — avaliação de `AirShortcutCore`

O target `AirShortcutCore` não foi extraído. A evidência do pacote atual é um
executável Swift `AirShortcut`, um target C local para o bridge de multitouch e
um target de testes que depende do executável. Embora os arquivos em `Models`
usem somente `Foundation`, eles participam de uma malha interna compartilhada
por codec, stores, engines, serviços, coordenadores e views.

Criar o módulo agora exigiria expor uma quantidade ampla de tipos atualmente
`internal`, mover consumidores que dependem de AppKit/ApplicationServices/
CoreGraphics/IOKit/SwiftUI ou criar adaptadores duplicados. Isso não atende ao
critério de fronteira pura sem dependência de plataforma e aumentaria o risco
da modernização incremental. A decisão é manter o target único e reavaliar a
extração somente quando houver um conjunto de consumidores independentes e uma
fronteira de visibilidade demonstrável.
