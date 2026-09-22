# Evidência de entrega — Tico V2

Data: 16/09/2026. Resultado geral: **PARTIAL**.

As sete frentes estão implementadas no working tree. Build SwiftPM e pacote ad hoc
passaram. O fechamento integral depende da suíte e de observação física. Não houve
commit, push, PR, publicação, mudança de versão nem aceite de licença pelo agente.

## Verificações executadas

| Verificação | Resultado |
| --- | --- |
| `DEVELOPER_DIR=/Library/Developer/CommandLineTools swift build --disable-sandbox --product Tico` | PASS no implementador e no verificador independente |
| `DEVELOPER_DIR=/Library/Developer/CommandLineTools TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/build_and_run.sh --package` | PASS; app, ZIP e DMG locais, verificação da assinatura ad hoc e checksum do DMG |
| `git diff --check` | PASS usando Git instalado no runtime, pois o Git via Xcode exige licença |
| `DEVELOPER_DIR=/Library/Developer/CommandLineTools swift test --disable-sandbox` | BLOCKED durante compilação: `no such module 'XCTest'`; zero testes executados |
| `TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package` | BLOCKED, exit 69 por licença do Xcode não aceita; a etapa inicial de sintaxe dos scripts passou |
| Novos testes/mocks/fixtures | Nenhum criado; arquivos de `Tests` sem alterações, conforme autorização |
| Assinatura Developer ID e notarização | NOT-RUN; assinatura ad hoc do pacote não representa distribuição pública |

## UAT nativo isolado

App executado com o modo `--ui-testing`, diretório próprio e suite de defaults
isolada. Somente regras sintéticas desativadas e uma cena sintética foram criadas.
Não foram concedidas permissões nem executadas automações reais. Inspeção por
acessibilidade e capturas visuais; dados privados, caches e logs brutos não foram lidos.

| Fluxo | Evidência observada |
| --- | --- |
| Explorar | PASS: categorias/cartões visíveis e receita de janela abre editor com regra desativada |
| Texto suportado | PASS: frase global gera prévia e é salva desativada; contexto Safari reconhecido depois de corrigir catálogo de apps do sistema |
| Texto inválido | PASS: `abra https://` recusado, sem rascunho |
| Cenas | PASS: editor, criação de cena nomeada e persistência após encerrar/reabrir app isolado |
| Regras | PASS: quatro regras sintéticas permanecem desativadas após reabrir |
| Mapa | PASS: lista com estado desativado, contexto, edição e prática |
| Prática sem TCC | PASS: tentativa mostra aviso de permissão e não apresenta sessão de treino |
| Painel contextual | PASS: menu abre painel nativo com contexto e quatro ações; Escape fecha, com captura pausada |
| Navegação pelo menu | PASS: comando Mapa de gestos muda a seção após correção de entrega do envelope publicado |

O painel inicialmente não abria. A investigação observou que outros comandos de
menu também eram ignorados. `@Published` emitia antes da atribuição e a verificação
de `consume` recusava o envelope; agendar o subscriber na main RunLoop corrigiu o
fluxo. Abertura do painel e navegação foram repetidas com o pacote recompilado.

## Revisão independente

Verificador em worktree separado revisou o diff, executou três builds e apontou
cinco problemas: suspensão/ownership, Hold na prática, relatório de cancelamento,
diagnóstico após timeout e URL sem host. Todos foram corrigidos e reinspecionados.
O [relatório independente](validation-review.md) preserva o histórico e os limites.
A correção posterior da entrega de comandos foi validada pelo implementador por
build e UAT; não deve ser atribuída à revisão independente anterior.

## Limites e validação manual pendente

- NOT-RUN: três sessões físicas distintas de swipe/Hold/sequência, restauração da
  captura e exclusão mútua entre janelas, gravador e Laboratório.
- NOT-RUN: tecla mantida/autorepeat durante treino de atalhos de teclado; a contagem
  física de pressões requer verificação, distinta da deduplicação de sessões trackpad.
- NOT-RUN: cola `⌘⌥`, atalho global do painel, foco/destino real de ações em outro app,
  Spaces, fullscreen e múltiplos monitores.
- NOT-RUN: efeitos/cancelamento de cena e relatório real por etapa; o modo isolado
  bloqueia efeitos de propósito. Verificação estática não substitui essa execução.
- NOT-RUN: retomada depois de pausa de 15 minutos, sleep/wake, hardware externo,
  VoiceOver e inspeção visual completa de light/dark mode.
- Cenas usam sequências explícitas da biblioteca existente; não há captura/restauração
  automática de qualquer layout. Perfis são associados pela regra que usa a cena.
- Texto usa gramática local restrita, sem LLM/rede e sem criação de código.

Para liberar a suíte, o usuário precisa concluir a licença do Xcode localmente
(`sudo xcodebuild -license`). Depois devem ser repetidos `swift test --disable-sandbox`
e `TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package` com Xcode disponível.

## Decisões e paralelo com React

SwiftUI, SwiftPM, macOS 26 e ObservableObject preservados. AppKit está em serviço
estreito; cenas reutilizam workflows e o schema v6 não mudou. Receitas e parser
entram pelo editor existente. Toda execução usa o coordenador/executor existente.

Paralelo com React: views recebem dados e callbacks; rascunhos são estado local,
stores têm responsabilidade compartilhada e suspensão é estado derivado. O token
da prática impede que o cleanup de uma janela encerre a sessão de outra. NSPanel,
captura global e permissões macOS não têm equivalente direto em React no navegador.

## Arquivos da entrega

### Modificados

- `.specs/STATE.md`
- `README.md`
- `Sources/Tico/App/Commands.swift`
- `Sources/Tico/App/TicoApp.swift`
- `Sources/Tico/Services/ApplicationCatalogService.swift`
- `Sources/Tico/Services/TriggerSequenceRuntime.swift`
- `Sources/Tico/Stores/ShortcutStore.swift`
- `Sources/Tico/Support/AppCommandRouter.swift`
- `Sources/Tico/Support/AppController.swift`
- `Sources/Tico/Support/AutomationCoordinator.swift`
- `Sources/Tico/Support/TicoSection.swift`
- `Sources/Tico/Views/ContentView.swift`
- `Sources/Tico/Views/MenuBarContentView.swift`
- `Sources/Tico/Views/RuleEditorView.swift`
- `Sources/Tico/Views/RulesView.swift`
- `Sources/Tico/Views/SidebarView.swift`
- `Sources/Tico/Views/WorkflowEditorView.swift`

### Criados

- `.specs/features/tico-v2/design.md`
- `.specs/features/tico-v2/spec.md`
- `.specs/features/tico-v2/tasks.md`
- `.specs/features/tico-v2/validation-review.md`
- `.specs/features/tico-v2/validation.md`
- `Sources/Tico/Models/AutomationExplanation.swift`
- `Sources/Tico/Models/AutomationRecipe.swift`
- `Sources/Tico/Services/AutomationDraftParser.swift`
- `Sources/Tico/Services/ContextualPanelService.swift`
- `Sources/Tico/Support/CompanionCoordinator.swift`
- `Sources/Tico/Support/GesturePracticeSession.swift`
- `Sources/Tico/Views/Components/ExecutionInsightView.swift`
- `Sources/Tico/Views/Components/GestureIllustrationView.swift`
- `Sources/Tico/Views/Components/WorkflowReportView.swift`
- `Sources/Tico/Views/ContextualActionsView.swift`
- `Sources/Tico/Views/DescribeAutomationView.swift`
- `Sources/Tico/Views/ExploreView.swift`
- `Sources/Tico/Views/GestureMapView.swift`
- `Sources/Tico/Views/GesturePracticeView.swift`
- `Sources/Tico/Views/SceneEditorView.swift`
- `Sources/Tico/Views/ScenesView.swift`
