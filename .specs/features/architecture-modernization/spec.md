# Spec: modernização arquitetural incremental

**Status:** implementação T01–T22 concluída; gates automatizados e validações manuais informadas pelo usuário registrados
**Feature key:** `architecture-modernization`  
**Stack preservada:** SwiftUI, Swift Package Manager e macOS 14+

## Problema

O projeto já possui separação nominal entre `App`, `Models`, `Services`, `Stores` e `Views`, mas algumas responsabilidades estão concentradas em poucos arquivos. `RuleEditorView` combina composição visual, edição, gravação e conflitos; `ShortcutStore` combina estado observável, persistência, migração e importação; `AppController` coordena estado de tela, captura, automações e serviços de plataforma.

Essa concentração torna mudanças pequenas mais arriscadas e deixa decisões arquiteturais implícitas. Agentes futuros podem ampliar os mesmos arquivos ou introduzir abstrações incompatíveis sem perceber os contratos existentes.

## Objetivo

Criar limites claros e verificáveis entre interface, estado de edição, aplicação, domínio, persistência e plataforma, sem reescrever o produto e sem alterar o comportamento percebido pelo usuário.

## Fora de escopo

- Redesenhar a interface, os fluxos ou a linguagem visual.
- Criar novas famílias de gestos ou regras.
- Renomear o produto técnico, bundle, chaves de preferências ou formatos persistidos de `AirShortcut`.
- Adicionar dependências externas.
- Migrar todo o projeto para `@Observable`, Swift 6 estrito ou uma arquitetura de terceiros.
- Declarar compatibilidade física, assinatura ou notarização sem os gates próprios.
- Criar novos arquivos de teste ou mocks sem autorização explícita do usuário.

## Premissas

1. A modernização será incremental e cada etapa deverá manter o app compilável.
2. `ObservableObject`, `@StateObject` e `@ObservedObject` continuam válidos; qualquer migração de Observation será uma decisão separada.
3. Primeiro serão criadas fronteiras dentro do target atual. Novos targets SwiftPM só serão introduzidos depois que o grafo de dependências estiver desacoplado e validado.
4. `Tico` é o nome público atual, enquanto nomes técnicos e contratos legados `AirShortcut` permanecem compatíveis.
5. Testes existentes podem ser ajustados junto da responsabilidade movida, mas não enfraquecidos ou removidos. Se uma tarefa realmente exigir um novo arquivo de teste, ela deverá parar e pedir aprovação.
6. Nenhum commit, push, PR ou publicação é autorizado apenas pela existência desta spec.

## Requisitos

### ARCH-01 — Preservação de contratos

**WHEN** uma responsabilidade for extraída ou movida  
**THEN** o sistema **SHALL** preservar comportamento, acessibilidade, atalhos, formatos persistidos, chaves de preferências, notificações externas e nomes técnicos de compatibilidade.

### ARCH-02 — Regras duráveis para agentes

**WHEN** um agente trabalhar no repositório  
**THEN** ele **SHALL** receber regras gerais pela raiz e regras especializadas pela pasta mais próxima, cobrindo arquitetura, segurança, testes, validação e limites de autorização.

### ARCH-03 — Editor de regras componível

**WHEN** o editor de regras for modificado  
**THEN** `RuleEditorView` **SHALL** atuar como composição de subviews e delegar transições de edição a um estado de sessão explícito, sem persistência ou lógica de plataforma no `body`.

### ARCH-04 — Persistência separada do estado observável

**WHEN** regras forem carregadas, migradas, importadas, exportadas ou salvas  
**THEN** `ShortcutStore` **SHALL** coordenar estado e invariantes, enquanto codec, acesso a arquivo e migração ficam atrás de fronteiras injetáveis e testáveis.

### ARCH-05 — Coordenação de aplicação separada

**WHEN** captura, automação ou laboratório forem acionados  
**THEN** `AppController` **SHALL** delegar cada fluxo a um coordenador com dependências explícitas e continuar como fachada compatível para as views durante a transição.

### ARCH-06 — Shell e integração macOS estreitos

**WHEN** comandos de menu, ciclo de vida ou APIs AppKit forem usados  
**THEN** o código **SHALL** expor ações tipadas e adaptadores estreitos, evitando ampliar comunicação global por `NotificationCenter` ou referências diretas a `NSApp` nas views.

### ARCH-07 — Fronteira de módulo validada

**WHEN** as dependências puras de domínio e persistência estiverem desacopladas de SwiftUI/AppKit  
**THEN** o projeto **SHALL** avaliar e, somente com gate verde, extrair um target interno `AirShortcutCore`; a extração não é obrigatória se aumentar acoplamento ou complexidade.

### ARCH-08 — Concorrência explícita

**WHEN** código atravessar threads, filas ou callbacks C/AppKit  
**THEN** o isolamento **SHALL** ser explícito; cada `@unchecked Sendable` existente ou novo deverá ter invariantes documentadas e ser auditado antes de qualquer adoção de Swift 6 estrito.

### ARCH-09 — Evidência proporcional ao risco

**WHEN** uma tarefa terminar  
**THEN** ela **SHALL** executar seu gate rápido, o gate da fase e registrar o que foi ou não foi validado; build automatizado não poderá ser apresentado como prova de trackpad físico, TCC, assinatura ou notarização.

### ARCH-10 — Documentação sincronizada

**WHEN** a arquitetura implementada divergir da documentação  
**THEN** `outputs/arquitetura.md`, as regras dos agentes e esta spec **SHALL** ser atualizadas na mesma fase, sem documentar uma estrutura ainda inexistente como concluída.

## Critérios de aceite

- As regras gerais e especializadas existem, têm escopo claro e não se contradizem.
- As tarefas em `tasks.md` mapeiam todos os requisitos e possuem dependências e gates explícitos.
- Ao final da execução futura, `RuleEditorView`, `ShortcutStore` e `AppController` são fachadas menores, sem perda de comportamento.
- O build do produto, a suíte existente e o gate canônico `./script/ci_verify.sh --package` passam.
- O número de testes não diminui sem justificativa e aprovação explícitas.
- A validação manual cobre criação, edição, conflito, importação/exportação, captura e automação; hardware continua sendo um gate separado.
- Nenhuma credencial, sessão, log bruto, banco de autenticação, gravação pessoal ou identificador sensível é incorporado como evidência.

## Rastreabilidade

| Requisito | Design | Tarefas |
|---|---|---|
| ARCH-01 | Compatibilidade e estratégia incremental | T01, T09, T12, T16, T22 |
| ARCH-02 | Regras em camadas | Artefatos já criados, T21 |
| ARCH-03 | Sessão e componentes do editor | T04–T09 |
| ARCH-04 | Codec, repositório e fachada | T10–T12 |
| ARCH-05 | Coordenadores e fachada | T13–T16 |
| ARCH-06 | Roteador de comandos e adaptador AppKit | T17–T19 |
| ARCH-07 | Target interno condicional | T20 |
| ARCH-08 | Auditoria de concorrência | T03, T13–T16, T22 |
| ARCH-09 | Matriz de validação | Todas; fechamento em T22 |
| ARCH-10 | Documentação final | T21 |
