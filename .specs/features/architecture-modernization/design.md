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
| Ciclo entre coordenadores | `Sources/AirShortcut/App/AppController.swift` conhece stores e vários serviços | Definir entradas/saídas pequenas e composition root único |
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
