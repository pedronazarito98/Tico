# STATE

## Decisions

### AD-001

- **Decision**: A iniciativa atual trata prontidão para release e validação do Tico existente; novas famílias de gestos ficam fora deste ciclo.
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
- **Status**: superseded by AD-011

### AD-006

- **Decision**: `Tico` é o nome público e técnico do produto, target, executável, bridge, bundle, diretório de dados, preferências e notificações internas.
- **Reason**: A migração nominal completa foi explicitamente aprovada após a modernização arquitetural.
- **Trade-off**: Instalações locais do preview anterior não são descobertas automaticamente pela nova identidade técnica.
- **Scope**: Código, pacote, persistência, testes e documentação técnica.
- **Date**: 2026-08-13
- **Status**: active

### AD-007

- **Decision**: Fronteiras serão criadas primeiro dentro do target atual; um target `TicoCore` só poderá ser extraído após análise de dependências e gate verde.
- **Reason**: Targets SwiftPM são limites de compilação fortes, mas uma divisão prematura pode expor ciclos e forçar mudanças simultâneas em acesso e plataforma.
- **Trade-off**: A separação física em módulos acontecerá mais tarde ou poderá ser rejeitada se não trouxer benefício líquido.
- **Scope**: `Package.swift` e organização de `Sources/Tico`.
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

### AD-010

- **Decision**: A avaliação T20 mantém um único target SwiftPM de implementação e não extrai `TicoCore` nesta modernização.
- **Reason**: Os modelos puros ainda integram uma malha interna ampla com stores, serviços, coordenadores e views; separar agora exigiria expor APIs ou mover dependências de plataforma sem consumidores independentes suficientes.
- **Trade-off**: A fronteira física de módulo fica para uma iniciativa futura somente se houver desacoplamento demonstrável.
- **Scope**: `Package.swift`, modelos, persistência e lógica compartilhada.
- **Date**: 2026-08-10
- **Status**: active

### AD-011

- **Decision**: O Tico passa a ser exclusivo do macOS 26; `Package.swift`, o bundle empacotado, o CI e a documentação devem declarar macOS 26 como versão mínima.
- **Reason**: O produto adotará diretamente as APIs e o comportamento visual do macOS 26, sem manter fallbacks de interface para macOS 14–25.
- **Trade-off**: O aplicativo deixa de instalar e executar no macOS 14–25, e o CI deixa de validar essas versões.
- **Scope**: Manifest SwiftPM, empacotamento, interface, CI, documentação e matriz de compatibilidade.
- **Date**: 2026-08-13
- **Status**: active

### AD-012

- **Decision**: O código da aplicação permanece no módulo SwiftPM `Tico`; o produto executável `Tico` usa o launcher fino `TicoLauncher`, e o App Target Xcode `TicoApp` usa `TicoXcodeApp`. Ambos iniciam o mesmo `TicoApp` e preservam o produto público `Tico.app`.
- **Reason**: Um host Xcode habilita Run, Profile, Archive e configuração de assinatura nativos sem duplicar views, domínio, serviços, resources ou o fluxo SwiftPM existente.
- **Trade-off**: O repositório passa a manter dois composition roots mínimos e precisa compilar ambos no gate; o target Xcode tem nome técnico diferente para não colidir com os produtos do package local.
- **Scope**: `Package.swift`, launchers, `Tico.xcodeproj`, configuração Xcode, CI e documentação de desenvolvimento/distribuição.
- **Date**: 2026-08-13
- **Status**: active

## Handoff

- **Feature**: `.specs/features/architecture-modernization/`
- **Phase / Task**: Pós-merge de T01–T22; App Target Xcode fino implementado conforme AD-012.
- **Completed**: Spec, modernização, exclusividade macOS 26, módulo compartilhado, launchers SwiftPM/Xcode, projeto e scheme compartilhados, configuração centralizada, gate do bundle e documentação.
- **In-progress**: Nenhum.
- **Next step**: Revisar o change set e solicitar autorização separada antes de commit, push ou PR.
- **Blockers**: A compatibilidade física e a release pública continuam `BLOCKED` pelos 22 cenários manuais `NOT-RUN` e por Developer ID/notarização/staple/Gatekeeper/máquina limpa.
- **Change set atual**: App Target Xcode fino preservando o código SwiftPM existente.
- **Branch**: `feat/xcode-thin-app-target`
- **Remote**: `NOT-RUN` — a branch ainda não foi publicada.
- **Pull request**: `NOT-RUN` — nenhum PR foi aberto para este change set.
- **Validação local**: `PASS` no gate canônico: builds SwiftPM e Xcode Debug, Archive Release universal com Hardened Runtime, 125 testes, 8 regressões de segurança, ZIP e DMG verificados.
- **CI remoto**: `NOT-RUN` para AD-012; o workflow foi atualizado localmente para incluir o App Target Xcode.
- **Release candidate**: `dist/Tico.zip` e `dist/Tico.dmg` com mínimo `26.0` validados localmente; preflight estrutural PASS, assinatura `ad-hoc/development`, sem release pública notarizada.
