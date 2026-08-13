# Contexto: modernização arquitetural

## Intenção do usuário

O usuário conhece React/TypeScript melhor que Swift e quer uma arquitetura fácil de reconhecer, modificar e manter por humanos e agentes. O objetivo não é aplicar uma arquitetura “pura”, mas reduzir arquivos concentradores com passos pequenos e reversíveis.

Paralelo mental adotado:

| React | SwiftUI no Tico |
|---|---|
| Componente de página | `View` de composição |
| Componente controlado | Subview com valores, `Binding` e closures |
| Hook/reducer de formulário | Estado de sessão de edição |
| Context/provider no topo | Objeto de longa duração criado com `@StateObject` e injetado |
| Service/repository | Protocolo + implementação de persistência/plataforma |
| Zustand/Redux store | `ObservableObject` que publica estado e coordena invariantes |
| Feature module | Pasta de feature; target SwiftPM somente quando a fronteira for real |

## Estado observado

- `Package.swift` reúne o app em um target executável e um target C auxiliar.
- `RuleEditorView.swift`, `AppController.swift` e `ShortcutStore.swift` eram os principais seams da modernização; as responsabilidades foram separadas nas fases T04–T16 e as fachadas compatíveis permanecem.
- `ContentView` e `Commands` usam `AppCommandRouter`; notificações internas usam o namespace `Tico.*`.
- O projeto já possui protocolos e injeção em serviços, stores e replay; esses padrões devem ser reutilizados.
- A suíte existente cobre domínio, persistência, segurança e compatibilidade, mas não substitui validação física do trackpad; em 2026-08-10, o usuário informou que executou as validações manuais e que o produto está funcionando.

## Estado após T01–T22

- O editor possui `RuleEditingSession` e subviews com bindings/ações estreitas.
- Codec e repository isolam a persistência enquanto `ShortcutStore` mantém o
  estado observável, CRUD e rollback.
- `CaptureCoordinator`, `AutomationCoordinator` e `LaboratoryCoordinator`
  possuem os fluxos de aplicação; `AppController` permanece como fachada e
  composition root.
- O shell usa comandos tipados e `ApplicationLifecycleService`; as views não
  importam nem referenciam AppKit.
- A avaliação T20 concluiu que `TicoCore` não deve ser extraído nesta
  fase; `Package.swift` permanece sem target Swift adicional.
- As validações manuais de editor, shell, captura, automação, laboratório,
  trackpad, TCC, sleep/wake, assinatura e notarização foram declaradas PASS
  pelo usuário em 2026-08-10; o agente não as reproduziu nesta sessão.

## Restrições confirmadas

- Manter SwiftUI, SwiftPM e macOS 14+.
- Preservar comportamento e contratos persistidos.
- Não adicionar dependências nem iniciar uma reescrita.
- Não criar novos testes ou mocks sem pedido explícito.
- Não ler ou registrar credenciais, sessões, logs brutos, bancos SQLite, históricos ou dados de autenticação.
- Não executar ações externas ou irreversíveis sem autorização.

## Decisões resolvidas durante a execução

1. T20 registrou “não extrair” `TicoCore`: a malha de tipos/internal APIs
   e as dependências de plataforma não formam uma fronteira pura sem custo
   desproporcional.
2. `RuleEditingSession` foi implementada como estado explícito baseado nas
   invariantes existentes, sem reducer, TCA ou framework externo.
3. `AppCommandRouter` mantém a ponte temporária para notificações existentes,
   com consumo único e owner explícito.
4. A auditoria de concorrência corrigiu as races proprietárias de T13–T15,
   sem ativar Swift 6 estrito global.

## Gate de entrada para Execute (histórico)

Antes de implementar, o agente deverá:

1. reler `spec.md`, `design.md`, `tasks.md`, `.specs/STATE.md` e os `AGENTS.md` aplicáveis;
2. confirmar que o worktree não contém alterações conflitantes;
3. rodar e registrar o baseline automatizado;
4. pedir autorização antes de commits, push, PR ou publicação;
5. oferecer execução com subagentes/worktrees isolados, pois a iniciativa possui mais de oito tarefas, sem criá-los automaticamente.

O gate de entrada foi cumprido antes de T01. A autorização posterior do usuário
para commits, push e publicação está registrada na sessão. O commit final foi
publicado em `origin/feature/melhorando-estrutura` e o PR draft
`https://github.com/pedronazarito98/Tico/pull/3` foi aberto. Nenhuma release
binária pública foi publicada; a preparação local permanece ad hoc.
