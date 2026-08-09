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
- `RuleEditorView.swift`, `AppController.swift` e `ShortcutStore.swift` concentram responsabilidades e são os principais seams da modernização.
- `ContentView` e `Commands` usam notificações para comandos internos do app.
- O projeto já possui protocolos e injeção em serviços, stores e replay; esses padrões devem ser reutilizados.
- A suíte existente cobre domínio, persistência, segurança e compatibilidade, mas não substitui validação física do trackpad.

## Restrições confirmadas

- Manter SwiftUI, SwiftPM e macOS 14+.
- Preservar comportamento e contratos persistidos.
- Não adicionar dependências nem iniciar uma reescrita.
- Não criar novos testes ou mocks sem pedido explícito.
- Não ler ou registrar credenciais, sessões, logs brutos, bancos SQLite, históricos ou dados de autenticação.
- Não executar ações externas ou irreversíveis sem autorização.

## Decisões em aberto durante a execução

1. O target `AirShortcutCore` só será criado se a análise de dependências da T20 comprovar uma fronteira limpa.
2. A forma final de `RuleEditingSession` será escolhida a partir das invariantes atuais; não se presume reducer, TCA ou framework externo.
3. O roteador tipado de comandos pode manter uma ponte temporária para notificações existentes até que todos os consumidores sejam migrados.
4. A auditoria de concorrência poderá recomendar, mas não ativar automaticamente, Swift 6 estrito.

## Gate de entrada para Execute

Antes de implementar, o agente deverá:

1. reler `spec.md`, `design.md`, `tasks.md`, `.specs/STATE.md` e os `AGENTS.md` aplicáveis;
2. confirmar que o worktree não contém alterações conflitantes;
3. rodar e registrar o baseline automatizado;
4. pedir autorização antes de commits, push, PR ou publicação;
5. oferecer execução com subagentes/worktrees isolados, pois a iniciativa possui mais de oito tarefas, sem criá-los automaticamente.
