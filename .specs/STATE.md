# STATE

## Decisions

### AD-001

- **Decision**: A iniciativa atual trata prontidão para release e validação do AirShortcut existente; novas famílias de gestos ficam fora deste ciclo.
- **Reason**: A implementação principal e a auditoria de segurança já existem; o risco restante é evidência operacional, compatibilidade física e distribuição.
- **Trade-off**: O produto não ampliará seu escopo funcional enquanto a matriz de validação e os gates de release não estiverem fechados.
- **Scope**: Todas as tarefas da iniciativa `release-readiness`.
- **Date**: 2026-07-26
- **Status**: active

### AD-002

- **Decision**: Testes automatizados cobrem domínio, persistência, replay, segurança e empacotamento; comportamento real do trackpad exige evidência manual versionada.
- **Reason**: Replay é determinístico e seguro para CI, mas não prova ABI privada, TCC, sleep/wake, reconexão ou falso positivo em uso normal.
- **Trade-off**: A aprovação final pode depender de uma sessão humana com hardware compatível.
- **Scope**: Pipeline CI, checklist de QA, relatório de hardware e gate final.
- **Date**: 2026-07-26
- **Status**: active

### AD-003

- **Decision**: A distribuição alvo é direta, fora da Mac App Store, com Developer ID e notarização; o build ad hoc permanece somente para desenvolvimento.
- **Reason**: A captura avançada carrega dinamicamente o framework privado `MultitouchSupport` e o app não é compatível com o modelo convencional da App Store.
- **Trade-off**: A publicação exige identidade Apple, Hardened Runtime e validação adicional em máquina limpa.
- **Scope**: Scripts de release, documentação e checklist de distribuição.
- **Date**: 2026-07-26
- **Status**: active

### AD-004

- **Decision**: Evidências commitadas no repositório não conterão identificadores de dispositivo, gravações pessoais brutas, credenciais ou dados de TCC.
- **Reason**: O laboratório pode observar contatos e dispositivos locais; o repositório é público.
- **Trade-off**: O relatório público será um resumo sanitizado, enquanto detalhes locais permanecem fora do Git.
- **Scope**: Templates de QA, relatórios, fixtures e release notes.
- **Date**: 2026-07-26
- **Status**: active

### AD-005

- **Decision**: A modernização arquitetural será incremental, preservando SwiftUI, SwiftPM, macOS 14+ e o comportamento atual; reescrita e novas dependências ficam fora da iniciativa.
- **Reason**: O projeto possui contratos e cobertura úteis; o principal risco está na concentração de responsabilidades, não na stack.
- **Trade-off**: Fachadas antigas e novas fronteiras poderão coexistir temporariamente.
- **Scope**: Iniciativa `architecture-modernization` e alterações estruturais relacionadas.
- **Date**: 2026-08-09
- **Status**: active

### AD-006

- **Decision**: `Tico` permanece o nome público, enquanto nomes técnicos, bundle, formatos persistidos e preferências `AirShortcut` permanecem compatíveis até uma migração explicitamente aprovada.
- **Reason**: Renomear contratos técnicos junto da refatoração ampliaria risco sem melhorar os limites arquiteturais.
- **Trade-off**: A árvore continuará exibindo nomenclatura legada em pontos técnicos.
- **Scope**: Código, pacote, persistência, testes e documentação técnica.
- **Date**: 2026-08-09
- **Status**: active

### AD-007

- **Decision**: Fronteiras serão criadas primeiro dentro do target atual; um target `AirShortcutCore` só poderá ser extraído após análise de dependências e gate verde.
- **Reason**: Targets SwiftPM são limites de compilação fortes, mas uma divisão prematura pode expor ciclos e forçar mudanças simultâneas em acesso e plataforma.
- **Trade-off**: A separação física em módulos acontecerá mais tarde ou poderá ser rejeitada se não trouxer benefício líquido.
- **Scope**: `Package.swift` e organização de `Sources/AirShortcut`.
- **Date**: 2026-08-09
- **Status**: active

### AD-008

- **Decision**: Padrões permanentes para agentes serão versionados em `AGENTS.md` na raiz e em pastas especializadas; `AGENTS.override.md` não será usado para regras permanentes.
- **Reason**: A precedência por diretório permite instruções precisas sem duplicar todo o manual e mantém overrides disponíveis para necessidades temporárias locais.
- **Trade-off**: Mudanças de padrão podem exigir atualizar mais de um arquivo quando afetarem áreas especializadas.
- **Scope**: Todo o repositório.
- **Date**: 2026-08-09
- **Status**: active

### AD-009

- **Decision**: O modelo atual baseado em `ObservableObject`, `@StateObject` e `@ObservedObject` será preservado nesta iniciativa; migração para Observation será avaliada separadamente.
- **Reason**: Trocar o mecanismo de observação junto da decomposição mistura mudança de estado com mudança estrutural e aumenta o risco de regressões de ciclo de vida.
- **Trade-off**: O projeto não adotará imediatamente as APIs de Observation mais recentes.
- **Scope**: Views, stores e controllers da iniciativa `architecture-modernization`.
- **Date**: 2026-08-09
- **Status**: active

## Handoff

- **Feature**: `.specs/features/architecture-modernization/`
- **Phase / Task**: Specify → Discuss → Design → Tasks concluídos; aguardando revisão antes de Execute.
- **Completed**: Spec, contexto, design, tarefas e regras em camadas para agentes.
- **In-progress**: Nenhum código de produto alterado; os artefatos definem uma modernização incremental.
- **Next step**: Revisar a proposta e autorizar explicitamente o Execute. Como há mais de oito tarefas, oferecer estratégia com worktrees/subagentes antes de iniciar.
- **Blockers**: Nenhum para revisão; execução depende de autorização e baseline verde. Hardware continua sendo gate separado.
- **Uncommitted files**: `.specs/STATE.md`, `.specs/features/architecture-modernization/`, `AGENTS.md` e regras especializadas.
- **Branch**: `feature/melhorando-estrutura`
