# Tasks: modernização arquitetural incremental

## Contrato de execução

- Ativar `tlc-spec-driven` no início do Execute e seguir esta ordem, salvo decisão registrada em `.specs/STATE.md`.
- Como existem mais de oito tarefas, oferecer subagentes com worktrees isolados antes do Execute; nunca criá-los automaticamente.
- Integração é serial. Um lote só começa após o gate da fase anterior ficar verde.
- Antes de qualquer commit, push, PR ou publicação, pedir autorização explícita ao usuário.
- Não criar novos arquivos de teste ou mocks. Se a cobertura necessária não couber em testes existentes, parar e pedir autorização.
- Não enfraquecer, apagar ou pular testes para obter verde.
- Registrar comandos, resultados e limitações em `validation.md`, a ser criado apenas durante o Execute.

## Matriz de validação

| Tipo de mudança | Teste no mesmo ciclo | Validação obrigatória |
|---|---|---|
| Subview/estado do editor | Ajustar testes existentes somente se afetados | Build, suíte existente e UAT de criar/editar/cancelar/conflito |
| Codec/repositório/store | `ShortcutStoreTests` e testes de segurança existentes | Round-trip, falha de arquivo, migração e importação/exportação |
| Coordenadores/controller | Suites existentes relacionadas ao fluxo | Estado inicial/final, cancelamento e ausência de execução duplicada |
| Menu/AppKit | Testes existentes quando aplicáveis | Comandos por menu/atalho e ciclo de vida manual |
| `Package.swift` | Suíte completa | Build do produto e dump/gate do pacote |
| Concorrência | Compilação e suites afetadas | Inventário de isolamento e ausência de novos warnings relevantes |

## Gates

**Gate rápido por tarefa**

```bash
git diff --check
swift build --disable-sandbox --product Tico
```

Adicionar a suíte existente diretamente relacionada, por exemplo:

```bash
swift test --disable-sandbox --filter ShortcutStoreTests
```

**Gate de fase**

```bash
swift test --disable-sandbox
```

**Gate final canônico**

```bash
TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package
```

O gate final não prova trackpad físico, TCC, assinatura Developer ID ou notarização.

## Fase 0 — Baseline e riscos

### T01 — Registrar baseline verificável

- **Requisitos:** ARCH-01, ARCH-09
- **Dependências:** nenhuma
- **Arquivos:** `validation.md` (novo durante Execute)
- **Ação:** registrar branch, estado do worktree, contagem de testes, build, suíte e gate canônico antes de código de produto.
- **Ferramentas:** `build-macos-apps:swiftpm-macos`.
- **Aceite:** baseline reproduzível, falhas classificadas e nenhuma alteração de produto.

### T02 — Mapear dependências dos três seams

- **Requisitos:** ARCH-03, ARCH-04, ARCH-05
- **Dependências:** T01
- **Arquivos:** `design.md`, `validation.md`
- **Ação:** confirmar produtores, consumidores, efeitos e ownership de `RuleEditorView`, `ShortcutStore` e `AppController`; atualizar o design apenas se a evidência atual divergir.
- **Aceite:** mapa sem dependências inferidas e lista de APIs que precisam permanecer compatíveis.

### T03 — Auditar fronteiras de concorrência

- **Requisitos:** ARCH-08
- **Dependências:** T01
- **Arquivos:** serviços que contêm filas, callbacks ou `@unchecked Sendable`; `validation.md`
- **Ação:** inventariar isolamento e invariantes. Esta tarefa é diagnóstica; não ativa Swift 6 estrito nem faz uma migração ampla.
- **Aceite:** cada fronteira classificada como segura, a corrigir em sua tarefa proprietária ou bloqueada por decisão.

## Fase 1 — Editor de regras

### T04 — Introduzir `RuleEditingSession`

- **Requisitos:** ARCH-03
- **Dependências:** T02
- **Arquivos:** novo estado na área de regras; `RuleEditorView.swift`; testes existentes afetados
- **Ação:** concentrar rascunho, dirty state, validação e transições sem IO/AppKit.
- **Ferramentas:** `build-macos-apps:view-refactor`, Context7 para SwiftUI quando necessário.
- **Aceite:** uma fonte de verdade para a edição e API explícita de salvar/cancelar.

### T05 — Extrair `TrackpadTriggerEditorView`

- **Requisitos:** ARCH-03
- **Dependências:** T04
- **Arquivos:** novo subcomponente; `RuleEditorView.swift`
- **Ação:** mover somente UI/configuração do gatilho de trackpad e suas ações explícitas.
- **Aceite:** gravação, seleção e feedback permanecem visual e funcionalmente equivalentes.

### T06 — Extrair `RuleTriggerEditorView`

- **Requisitos:** ARCH-03
- **Dependências:** T05
- **Arquivos:** novo subcomponente; `RuleEditorView.swift`
- **Ação:** compor os tipos de gatilho sem carregar store/controller completos.
- **Aceite:** troca de gatilho preserva rascunho e regras de conflito atuais.

### T07 — Extrair cabeçalho do editor

- **Requisitos:** ARCH-03
- **Dependências:** T04
- **Arquivos:** `RuleEditorHeaderView.swift`; `RuleEditorView.swift`
- **Ação:** mover apenas identificação, título e chrome do editor.
- **Aceite:** layout e acessibilidade permanecem equivalentes.

### T08 — Extrair rodapé e ações

- **Requisitos:** ARCH-03
- **Dependências:** T04
- **Arquivos:** `RuleEditorFooterView.swift`; `RuleEditorView.swift`
- **Ação:** tornar cancelar/salvar ações explícitas, sem persistir dentro da subview.
- **Aceite:** estados habilitado/desabilitado e atalhos permanecem equivalentes.

### T09 — Consolidar `RuleEditorView` como composição

- **Requisitos:** ARCH-01, ARCH-03
- **Dependências:** T05, T06, T07, T08
- **Arquivos:** `RuleEditorView.swift`; consumidores diretos
- **Ação:** remover duplicação transitória e deixar o arquivo como dono da composição e adaptação externa.
- **Gate da fase:** suíte completa + UAT do editor.
- **Aceite:** nenhum estado duplicado, nenhuma persistência no `body` e contratos externos preservados.

## Fase 2 — Persistência e store

### T10 — Extrair `ShortcutDocumentCodec`

- **Requisitos:** ARCH-04
- **Dependências:** T02, T09
- **Arquivos:** novo codec/modelos de documento; `ShortcutStore.swift`; testes existentes
- **Ação:** isolar encode/decode, versão e migração pura, preservando bytes e semântica aceitos.
- **Aceite:** documentos atuais e legados mantêm round-trip e erros tipados.

### T11 — Introduzir `ShortcutRepository`

- **Requisitos:** ARCH-04
- **Dependências:** T10
- **Arquivos:** protocolo e implementação de arquivo; `ShortcutStore.swift`; testes existentes
- **Ação:** encapsular leitura/escrita/importação/exportação com política de segurança e escrita atômica existentes.
- **Aceite:** falha de IO não destrói último estado válido; paths continuam injetáveis.

### T12 — Reduzir `ShortcutStore` a fachada de estado

- **Requisitos:** ARCH-01, ARCH-04
- **Dependências:** T11
- **Arquivos:** `ShortcutStore.swift`; consumidores; testes existentes
- **Ação:** manter estado publicado, CRUD e invariantes, delegando documento e IO.
- **Gate da fase:** suíte completa, incluindo store e segurança.
- **Aceite:** API compatível ou migração de consumidores no mesmo diff; persistência fora da fachada.

## Fase 3 — Coordenação de aplicação

### T13 — Extrair `CaptureCoordinator`

- **Requisitos:** ARCH-05, ARCH-08
- **Dependências:** T03, T12
- **Arquivos:** novo coordenador; `AppController.swift`; serviços de captura afetados
- **Ação:** concentrar início, cancelamento, resultado e isolamento da captura.
- **Aceite:** uma captura ativa por vez e cancelamento idempotente.

### T14 — Extrair `AutomationCoordinator`

- **Requisitos:** ARCH-05, ARCH-08
- **Dependências:** T03, T12
- **Arquivos:** novo coordenador; `AppController.swift`; runtime afetado
- **Ação:** encapsular ativação, execução contínua e feedback sem duplicar observers.
- **Aceite:** habilitar/desabilitar preserva semântica e não executa ação duplicada.

### T15 — Extrair `LaboratoryCoordinator`

- **Requisitos:** ARCH-05, ARCH-08
- **Dependências:** T03, T12
- **Arquivos:** novo coordenador; `AppController.swift`; serviços de laboratório afetados
- **Ação:** encapsular gravação/replay/estado do laboratório e seus limites de segurança.
- **Aceite:** replay continua sem executar regras reais e dados sensíveis não são registrados.

### T16 — Consolidar `AppController` como composition root/fachada

- **Requisitos:** ARCH-01, ARCH-05
- **Dependências:** T13, T14, T15
- **Arquivos:** `AppController.swift`; views consumidoras
- **Ação:** remover lógica já delegada, manter projeções publicadas necessárias e construir dependências explicitamente.
- **Gate da fase:** suíte completa + UAT de captura, automação e laboratório.
- **Aceite:** nenhuma assinatura pública é removida antes da migração de seus consumidores.

## Fase 4 — Shell macOS e módulo

### T17 — Introduzir `AppCommandRouter`

- **Requisitos:** ARCH-06
- **Dependências:** T16
- **Arquivos:** `TicoApp.swift`, `ContentView.swift`, novo roteador
- **Ação:** definir comandos internos tipados e uma ponte temporária, se necessária, para notificações legadas.
- **Aceite:** cada comando tem um único owner e é processado uma vez.

### T18 — Isolar ciclo de vida AppKit

- **Requisitos:** ARCH-06
- **Dependências:** T17
- **Arquivos:** adaptador de ciclo de vida; app/menu/views afetados
- **Ação:** mover operações `NSApplication` para uma interface estreita e injetável.
- **Ferramentas:** `build-macos-apps:appkit-interop` se a integração exigir nova ponte.
- **Aceite:** views SwiftUI não ganham novas referências diretas a AppKit.

### T19 — Afinar o shell de views

- **Requisitos:** ARCH-06
- **Dependências:** T17, T18
- **Arquivos:** `ContentView.swift`, `TicoApp.swift`
- **Ação:** deixar seleção, navegação e composição visíveis; efeitos seguem ações tipadas.
- **Gate da fase:** suíte completa + UAT de menus, atalhos e janelas.
- **Aceite:** navegação e comportamento de janela permanecem estáveis.

### T20 — Avaliar e extrair `TicoCore` condicionalmente

- **Requisitos:** ARCH-07
- **Dependências:** T19
- **Arquivos:** `Package.swift`; modelos/lógica pura aprovados pela análise
- **Ação:** documentar o grafo. Extrair um único target interno somente se ele não depender de SwiftUI/AppKit/bridge C e não criar ciclos.
- **Ferramentas:** `build-macos-apps:swiftpm-macos`, Context7 para SwiftPM.
- **Aceite:** build e suíte completos verdes; se o critério não for atendido, registrar “não extrair” como resultado válido.

## Fase 5 — Sincronização e encerramento

### T21 — Atualizar arquitetura e regras

- **Requisitos:** ARCH-02, ARCH-10
- **Dependências:** T20
- **Arquivos:** `outputs/arquitetura.md`, `CONTRIBUTING.md`, `AGENTS.md` aplicáveis, spec/design
- **Ação:** documentar somente a estrutura efetivamente entregue e remover instruções transitórias.
- **Aceite:** documentação, árvore de arquivos e regras não se contradizem.

### T22 — Executar gate final e UAT

- **Requisitos:** ARCH-01, ARCH-08, ARCH-09
- **Dependências:** T21
- **Arquivos:** `validation.md`, handoff em `.specs/STATE.md`
- **Ação:** executar gate canônico, revisar contagem de testes e realizar checklist manual. Hardware, assinatura e notarização ficam explicitamente separados.
- **Aceite:** evidências registradas; falhas não mascaradas; handoff aponta resultado, limitações e próximo gate real.

## Dependências resumidas

```text
T01 → T02 ─┬→ T04 → T05 → T06 ─┐
           │         ├→ T07 ────┼→ T09 → T10 → T11 → T12
           │         └→ T08 ────┘                   │
           └→ T03 ─────────────────────────────────┼→ T13 ─┐
                                                   ├→ T14 ─┼→ T16
                                                   └→ T15 ─┘
T16 → T17 → T18 → T19 → T20 → T21 → T22
```

## Sugestão de lotes isolados

| Lote | Tarefas | Ownership principal | Integração |
|---|---|---|---|
| A | T01–T03 | specs/diagnóstico | primeiro |
| B | T04–T09 | `Views` + estado de edição | após A |
| C | T10–T12 | `Stores` + persistência | após B |
| D | T13–T16 | `App` + coordenadores | após C |
| E | T17–T20 | shell + `Package.swift` | após D |
| F | T21–T22 | documentação/validação | último |

Mesmo com subagentes, tarefas que editam `RuleEditorView`, `ShortcutStore`, `AppController` ou `Package.swift` não devem ser integradas em paralelo.
