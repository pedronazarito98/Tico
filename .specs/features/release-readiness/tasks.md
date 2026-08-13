# Tico Release Readiness Tasks

## Execution Protocol (MANDATORY)

Implement these tasks with the `tlc-spec-driven` skill. Every task follows
implement → test gate → atomic commit. Tests derive from `spec.md`; they do
not mirror implementation details. Nunca enfraquecer ou remover testes para
fazer um gate passar.

O ciclo tem **19 tarefas de implementação em 5 fases**, portanto deve ser
executado em **3 lotes sequenciais de agentes**, respeitando fronteiras de
fase. O Verifier é um agente novo e separado, executado automaticamente
depois de T19; ele não é o autor das mudanças e não altera o working tree real.

Antes de Execute, o orquestrador deve confirmar com o usuário quais MCPs e
skills serão usados por tarefa. Defaults deste plano: `exec_command`/`apply_patch`,
GitHub Actions/GitHub quando disponível, `tlc-spec-driven`,
`build-macos-apps:swiftpm-macos`, `build-macos-apps:build-run-debug`,
`build-macos-apps:test-triage`, `build-macos-apps:packaging-notarization` e
`build-macos-apps:signing-entitlements`.

**Design**: `.specs/features/release-readiness/design.md`
**Status**: Draft — aguardando aprovação

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec — confirm before Execute. Guidelines found: `README.md`, `SECURITY.md`, `outputs/qa-checklist.md`, `Package.swift`; no `AGENTS.md`/`CONTRIBUTING.md`/CI found — strong defaults applied.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| Domain, recognizers and workflows | unit | Todos os branches relevantes; 1:1 com ACs RR-09, RR-10 e regressões listadas | `Tests/TicoTests/*Gesture*Tests.swift`, `AdvancedPhasesTests.swift` | `swift test` |
| Persistence, importação e segurança | unit | Todos os limites, rejeições, ativação e compatibilidade descritos pela auditoria | `Tests/TicoTests/SecurityRegressionTests.swift`, `ShortcutStoreTests.swift` | `swift test --filter SecurityRegressionTests` e `swift test` |
| Replay e isolamento de ações | unit/integration | Cada velocidade, fixture válida, estado do laboratório e ausência de execução de regra | `Tests/TicoTests/TrackpadLaboratoryPhaseOneTests.swift`, `AdvancedPhasesTests.swift` | `swift test` |
| Scripts de build/package/report | shell/build | Happy path, erro controlado, sintaxe e artefato extraído verificável | `script/*.sh`, fixtures de `outputs/hardware-validation/` | `bash -n ...` e `./script/ci_verify.sh --package` |
| UI, permissões e fallback | manual UAT | Fluxos de permissão, laboratório, captura privada, fallback e mensagens observáveis | app SwiftUI + `outputs/qa-checklist.md` | `./script/build_and_run.sh --laboratory-verify` + sessão manual |
| Hardware físico | manual hardware | Todas as linhas obrigatórias de RR-07–RR-10; `NOT-RUN` nunca conta como PASS | `outputs/hardware-validation/` | checklist no Mac compatível |
| Assinatura e distribuição | manual release | App bundle, nested code, Hardened Runtime, notarização, staple e máquina limpa | `outputs/signing-and-distribution.md`, release artifact | comandos `codesign`, `spctl`, `notarytool`, `stapler` |
| Markdown/configuração | none | Build gate e revisão de consistência; sem teste unitário artificial | `README.md`, `SECURITY.md`, `.github/` | `git diff --check` + build gate |

## Gate Check Commands

> Generated from codebase — confirm before Execute.

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | Após tarefa somente de teste/unit ou documentação com impacto local | `swift test` |
| Full | Após tarefa de código, replay, segurança ou integração | `swift build --product Tico && swift test && swift test --filter SecurityRegressionTests` |
| Build | Após fase e antes de mover para o próximo lote | `bash -n script/build_and_run.sh && ./script/ci_verify.sh --package` |

**Local recovery only**: se o cache SwiftPM do ambiente causar `ModuleCache:
Operation not permitted`, repetir com `swift test --disable-sandbox` e registrar
isso como condição ambiental; não transformar uma falha de fonte em PASS.

**Co-located tests**: toda tarefa que alterar domínio, persistência, replay ou
script com cobertura exigida deve alterar seus testes/fixtures na mesma tarefa.
Testes de hardware e notarização são manuais e devem gerar evidência sanitizada.

## Execution Plan

### Phase 1: Foundation — 3 tasks

```text
T1 → T2 → T3
```

### Phase 2: Public contract — 4 tasks

```text
T4 → T5 → T6
         └→ T7
```

### Phase 3: Evidence and regression — 5 tasks

```text
T8 → T9 ─┐
   ├→ T10 ├→ T12
   └→ T11 ┘
```

### Phase 4: Distribution — 4 tasks

```text
T13 → T14 → T15 → T16
```

### Phase 5: Close — 3 tasks

```text
{T12,T16} → T17 → T18 → T19
```

### Batch Execution Map

| Batch | Phases | Tasks | Agent contract |
| --- | --- | --- | --- |
| Batch 1 | 1 + 2 | T1–T7 (7) | CI, documentação pública e contrato de contribuição; terminar com Build gate. |
| Batch 2 | 3 | T8–T12 (5) | Fixtures/relatórios, regressões replay/fallback e execução assistida da matriz física. |
| Batch 3 | 4 + 5 | T13–T19 (7) | Preflight de release, dry-run, checklist final e release notes; terminar com Full/Build gate. |
| Verifier | após Batch 3 | automático | Agente independente: evidence-or-zero, sensor de 1–3 mutações, `validation.md` e lessons quando houver sinal. |

## Task Breakdown

### T1: Criar o gate local compartilhado

**What**: Criar `script/ci_verify.sh` para executar build, testes, regressões
de segurança, sintaxe do build script e package verification sem abrir o app.
**Where**: `script/ci_verify.sh`
**Depends on**: None
**Reuses**: `Package.swift`, `script/build_and_run.sh`
**Requirement**: RR-01, RR-02

**Tools**: `exec_command`, `apply_patch`; skills `tlc-spec-driven`, `build-macos-apps:swiftpm-macos`.

**Done when**:

- [ ] O script tem `set -euo pipefail`, mensagens por etapa e exit code não-zero em qualquer falha.
- [ ] O modo padrão não abre a aplicação e o modo package verifica o ZIP extraído.
- [ ] O resumo informa test count e paths de artefato sem afirmar hardware/notarização.
- [ ] `bash -n script/ci_verify.sh` e o gate rápido passam.

**Tests**: shell/build
**Gate**: Build
**Commit**: `ci: add shared macOS verification gate`

### T2: Adicionar GitHub Actions para pull requests e main

**What**: Criar o workflow macOS que chama somente o gate compartilhado e
publica logs/resumo sem mascarar falhas.
**Where**: `.github/workflows/ci.yml`
**Depends on**: T1
**Reuses**: `script/ci_verify.sh`
**Requirement**: RR-01, RR-03

**Tools**: `apply_patch`, GitHub/`git`; skills `tlc-spec-driven`, `github:github` quando o conector estiver disponível.

**Done when**:

- [ ] Pull requests e pushes em `main` acionam o workflow.
- [ ] O workflow usa permissões mínimas, não contém segredos e não tenta capturar hardware.
- [ ] Falha de qualquer etapa faz o job falhar.
- [ ] O summary diferencia automated coverage de physical coverage.

**Tests**: none
**Gate**: Build
**Commit**: `ci: run macOS verification on pull requests`

### T3: Documentar o gate e seus artefatos

**What**: Adicionar ao README o comando canônico local, fallback de cache e
contrato dos artefatos CI.
**Where**: `README.md`
**Depends on**: T2
**Reuses**: comandos existentes de Run/Package/Verify
**Requirement**: RR-02, RR-03

**Tools**: `apply_patch`; skills `tlc-spec-driven`, `build-macos-apps:swiftpm-macos`.

**Done when**:

- [ ] Um contribuinte consegue executar o gate sem abrir a UI.
- [ ] A documentação diz que CI não valida hardware físico.
- [ ] O comando de recuperação `swift test --disable-sandbox` é apresentado como exceção ambiental.
- [ ] `git diff --check` e o Build gate passam.

**Tests**: none
**Gate**: Build
**Commit**: `docs: document reproducible verification gate`

### T4: Confirmar e adicionar licença e guia de contribuição

**What**: Confirmar com o proprietário a licença adequada e adicionar o arquivo
legal correspondente; documentar o fluxo mínimo de contribuição sem inventar
autorização legal.
**Where**: `LICENSE`, `CONTRIBUTING.md` ou decisão explícita de bloqueio
**Depends on**: None
**Reuses**: `SECURITY.md`, README
**Requirement**: RR-05

**Tools**: `apply_patch`; skill `tlc-spec-driven`.

**Done when**:

- [ ] A licença foi escolhida pelo proprietário ou a ausência está marcada como blocker.
- [ ] O texto não contradiz dependências ou intenção pública do projeto.
- [ ] O guia aponta para build, testes, segurança e limites de hardware.

**Tests**: none
**Gate**: Quick
**Commit**: `docs: define open source contribution contract`

### T5: Reescrever o status público do README

**What**: Alinhar README com comportamento atual, incluindo technical preview,
`MultitouchSupport`, fallback, permissões, ad hoc e distribuição fora da App Store.
**Where**: `README.md`
**Depends on**: T4
**Reuses**: `outputs/signing-and-distribution.md`, `outputs/trackpad-research.md`
**Requirement**: RR-04, RR-05

**Tools**: `apply_patch`; skills `tlc-spec-driven`, `build-macos-apps:packaging-notarization`.

**Done when**:

- [ ] O status não usa “stable” nem promete compatibilidade universal.
- [ ] O atalho do laboratório aparece como `⌘6`.
- [ ] A diferença entre private capture, fallback público, replay e hardware real está explícita.
- [ ] O README aponta para os relatórios de segurança e distribuição.

**Tests**: none
**Gate**: Quick
**Commit**: `docs: clarify preview status and platform limitations`

### T6: Corrigir e tornar executável o checklist de QA

**What**: Atualizar `outputs/qa-checklist.md` para `⌘6`, separar gates
automatizados/manuais e transformar cada cenário em resultado PASS/FAIL/NOT-RUN.
**Where**: `outputs/qa-checklist.md`
**Depends on**: T5
**Reuses**: `TrackpadValidationView`, checklist existente
**Requirement**: RR-04, RR-07, RR-10

**Tools**: `apply_patch`; skills `tlc-spec-driven`, `build-macos-apps:build-run-debug`.

**Done when**:

- [ ] Não existe referência contraditória a `⌘4`.
- [ ] O checklist inclui tap/hold, quatro swipes, pinch, rotação, sleep/wake, reconexão, fallback e falso positivo.
- [ ] Cada linha tem expected, observed, status e notes.
- [ ] `NOT-RUN` é explicitamente diferente de PASS.

**Tests**: none
**Gate**: Quick
**Commit**: `docs: make trackpad QA matrix executable`

### T7: Fechar documentação de segurança e release

**What**: Ajustar `SECURITY.md` e `outputs/signing-and-distribution.md` para explicar reporte privado, dry-run ad hoc, Developer ID, notarização e clean Mac.
**Where**: `SECURITY.md`, `outputs/signing-and-distribution.md`
**Depends on**: T5
**Reuses**: relatórios de correções e evidências existentes
**Requirement**: RR-06, RR-12, RR-13, RR-14

**Tools**: `apply_patch`; skills `tlc-spec-driven`, `build-macos-apps:packaging-notarization`, `build-macos-apps:signing-entitlements`.

**Done when**:

- [ ] Vulnerabilidades não são direcionadas para issue pública.
- [ ] Ad hoc não é descrito como notarizado/Gatekeeper-ready.
- [ ] O fluxo Developer ID exige Hardened Runtime, nested signing, notarização, staple e máquina limpa.
- [ ] A documentação indica que credenciais Apple não entram no repositório.

**Tests**: none
**Gate**: Quick
**Commit**: `docs: clarify security reporting and distribution gates`

### T8: Criar o pacote de evidência de hardware

**What**: Criar template, README e exemplo sanitizado para a matriz física.
**Where**: `outputs/hardware-validation/README.md`, `report-template.md`, `sample-report.md`
**Depends on**: T6
**Reuses**: checklist, modelos do design
**Requirement**: RR-07, RR-08, RR-10

**Tools**: `apply_patch`; skills `tlc-spec-driven`, `build-macos-apps:build-run-debug`.

**Done when**:

- [ ] Todas as colunas de `SanitizedHardwareRow` existem.
- [ ] O template exige OS, classe do dispositivo, modo, gesto, esperado, observado, status e notes.
- [ ] O README proíbe serial, TCC dump, username e frames brutos.
- [ ] O exemplo demonstra PASS, FAIL e NOT-RUN sem dados pessoais.

**Tests**: none
**Gate**: Quick
**Commit**: `qa: add sanitized trackpad evidence pack`

### T9: Criar validador de relatório sanitizado

**What**: Criar um script que rejeita linhas ausentes, status inválido e marcadores sensíveis no relatório antes de commit.
**Where**: `script/validate_hardware_report.sh`, fixtures mínimas
**Depends on**: T8
**Reuses**: schema de `design.md`
**Requirement**: RR-07, RR-08

**Tools**: `apply_patch`, `exec_command`; skill `tlc-spec-driven`.

**Done when**:

- [ ] Relatório válido retorna zero.
- [ ] Relatório com coluna obrigatória ausente retorna não-zero.
- [ ] `serial`, `TCC`, caminhos pessoais ou conteúdo bruto são rejeitados.
- [ ] `bash -n` e os casos válido/inválido passam com resultado esperado.

**Tests**: shell/build
**Gate**: Quick
**Commit**: `qa: validate sanitized hardware reports`

### T10: Fortalecer testes de isolamento do replay

**What**: Adicionar/ajustar testes que provem estado do laboratório em cada velocidade e ausência de execução de regra/action log.
**Where**: `Tests/TicoTests/TrackpadLaboratoryPhaseOneTests.swift`, `AdvancedPhasesTests.swift`
**Depends on**: T8
**Reuses**: `ReplayFrameProvider`, fixtures existentes
**Requirement**: RR-09

**Tools**: `apply_patch`, `exec_command`; skills `tlc-spec-driven`, `build-macos-apps:swiftpm-macos`, `build-macos-apps:test-triage`.

**Done when**:

- [ ] 0.5×, 1× e 2× são exercitados.
- [ ] O snapshot/progresso esperado é assertado por valor, não apenas por chamada.
- [ ] O log de ações permanece inalterado após replay.
- [ ] O Full gate passa sem reduzir a contagem anterior de testes.

**Tests**: unit/integration
**Gate**: Full
**Commit**: `test: prove replay never executes actions`

### T11: Fortalecer testes de permissão e fallback

**What**: Adicionar/ajustar regressões para captura negada, fallback público e segurança de teclado/mouse quando o private provider não está disponível.
**Where**: `Tests/TicoTests/TrackpadGestureServiceTests.swift`, `PermissionCoordinatorTests.swift`, provider tests quando necessário
**Depends on**: T8
**Reuses**: `PermissionCoordinator`, `TrackpadFrameProvider`
**Requirement**: RR-08, RR-10

**Tools**: `apply_patch`, `exec_command`; skills `tlc-spec-driven`, `build-macos-apps:swiftpm-macos`, `build-macos-apps:test-triage`.

**Done when**:

- [ ] Captura não inicia sem autorização atualizada.
- [ ] Fallback é identificável e não consome keyboard/mouse original.
- [ ] O estado de capability e a mensagem de erro são assertados.
- [ ] O Full gate passa.

**Tests**: unit/integration
**Gate**: Full
**Commit**: `test: cover trackpad permission and fallback states`

### T12: Executar a matriz física e publicar resumo sanitizado

**What**: Executar o checklist no Mac disponível, registrar evidências e commitar somente o relatório sanitizado.
**Where**: `outputs/hardware-validation/report-YYYY-MM-DD.md`
**Depends on**: T9, T10, T11
**Reuses**: app build, laboratório, `--laboratory-verify`, fallback diagnostic
**Requirement**: RR-07, RR-08, RR-10

**Tools**: `exec_command`, interação humana/hardware; skills `tlc-spec-driven`, `build-macos-apps:build-run-debug`, `build-macos-apps:swiftpm-macos`.

**Done when**:

- [ ] Cada linha obrigatória tem PASS, FAIL ou NOT-RUN e observação objetiva.
- [ ] Internal trackpad e Magic Trackpad são distinguidos; ausência de Magic Trackpad fica NOT-RUN.
- [ ] Sleep/wake, reconexão e falso positivo são realmente executados ou marcados NOT-RUN.
- [ ] O validador T9 passa e nenhum dado sensível é commitado.

**Tests**: manual hardware
**Gate**: Full + UAT
**Commit**: `qa: record sanitized physical trackpad validation`

### T13: Criar release preflight separado do build local

**What**: Criar preflight que identifica modo ad hoc/Developer ID, valida bundle, nested code, entitlements e ZIP extraído sem abrir a aplicação.
**Where**: `script/release_preflight.sh` ou extensão cirúrgica documentada de `script/build_and_run.sh`
**Depends on**: T3
**Reuses**: staging privado, `codesign --verify`, ZIP extraction existente
**Requirement**: RR-11, RR-12, RR-13

**Tools**: `apply_patch`, `exec_command`; skills `tlc-spec-driven`, `build-macos-apps:packaging-notarization`, `build-macos-apps:signing-entitlements`.

**Done when**:

- [ ] Sem identidade Developer ID, o resultado é explicitamente ad hoc/development.
- [ ] O app extraído em diretório temporário passa `codesign --verify --deep --strict`.
- [ ] O preflight não afirma notarização sem evidência de aceitação.
- [ ] O script e o package dry-run passam.

**Tests**: shell/build
**Gate**: Build
**Commit**: `release: add honest package preflight`

### T14: Criar contrato de metadados e release notes

**What**: Criar template que registra versão, SHA, mínimo macOS, signing mode, notarization, staple, clean-machine e limitações.
**Where**: `outputs/release-template.md`, eventual metadata gerado pelo script
**Depends on**: T13
**Reuses**: `ReleaseEvidence`, `outputs/signing-and-distribution.md`
**Requirement**: RR-14

**Tools**: `apply_patch`; skills `tlc-spec-driven`, `build-macos-apps:packaging-notarization`.

**Done when**:

- [ ] O template não permite marcar notarized sem acceptance evidence.
- [ ] Ad hoc e Developer ID são estados diferentes.
- [ ] O release note aponta para commit e artefato verificável.

**Tests**: none
**Gate**: Quick
**Commit**: `release: add evidence-backed release template`

### T15: Executar dry-run de empacotamento e signing review

**What**: Produzir um artefato ad hoc de dry-run, revisar entitlements e registrar a saída de assinatura sem apresentá-lo como release.
**Where**: `outputs/release-dry-run-*.md` (sanitizado), `dist/Tico.zip` local
**Depends on**: T13, T14
**Reuses**: package script e artifact atual
**Requirement**: RR-11, RR-12, RR-14

**Tools**: `exec_command`; skills `tlc-spec-driven`, `build-macos-apps:packaging-notarization`, `build-macos-apps:signing-entitlements`.

**Done when**:

- [ ] O ZIP extraído passa strict verification.
- [ ] A revisão registra identidade, bundle ID, versão e ausência/presença de entitlements.
- [ ] O relatório chama o artefato de ad hoc/dry-run.
- [ ] Nenhuma credencial ou caminho pessoal é publicado.

**Tests**: manual release/build
**Gate**: Build
**Commit**: `release: record ad hoc package dry run`

### T16: Validar Developer ID, notarização e máquina limpa quando disponível

**What**: Com identidade Apple fornecida pelo proprietário, assinar, notarizar, staple e executar em máquina/usuário limpo; sem identidade, registrar blocker.
**Where**: release artifact externo e `outputs/release-validation-*.md`
**Depends on**: T15
**Reuses**: `outputs/signing-and-distribution.md`
**Requirement**: RR-13, RR-14

**Tools**: `exec_command`; skills `tlc-spec-driven`, `build-macos-apps:packaging-notarization`, `build-macos-apps:signing-entitlements`.

**Done when**:

- [ ] Nested signing, Hardened Runtime, notarization acceptance, staple e `stapler validate` têm evidência, ou o estado é `not-attempted` com blocker explícito.
- [ ] `spctl` e execução em máquina limpa são registrados quando o artifact existe.
- [ ] Segredos ficam fora de logs, commits e release notes.

**Tests**: manual release
**Gate**: Full + UAT
**Commit**: `release: validate distribution artifact` (somente se houver mudança de evidência)

### T17: Criar checklist final de readiness e mapa de status

**What**: Consolidar automated, physical, security, packaging e documentation gates em uma decisão objetiva de `READY`, `PREVIEW` ou `BLOCKED`.
**Where**: `outputs/release-readiness-checklist.md`
**Depends on**: T12, T16
**Reuses**: todos os relatórios e RR-01–RR-14
**Requirement**: RR-03, RR-10, RR-12, RR-14

**Done when**:

- [ ] Cada P1 requirement possui evidência ou blocker.
- [ ] `NOT-RUN` obrigatório impede `READY` físico.
- [ ] Ad hoc impede classificação de distribuição notarizada.
- [ ] O documento aponta para logs/artefatos sem incorporar dados sensíveis.

**Tests**: none
**Gate**: Build
**Commit**: `docs: add release readiness decision checklist`

### T18: Preparar release notes e issues de acompanhamento

**What**: Criar release notes de technical preview e abrir/registrar issues para gaps que não impedem publicação do código, sem fechar gaps por retórica.
**Where**: `CHANGELOG.md` ou `outputs/release-notes-template.md`, GitHub issues
**Depends on**: T17
**Reuses**: readiness checklist e SECURITY.md
**Requirement**: RR-03, RR-14, RR-18

**Done when**:

- [ ] Release notes declaram baseline, testes, hardware validado, limitações e assinatura.
- [ ] Cada gap tem issue com critério de aceite e sem dados privados.
- [ ] Nenhum “stable”, “notarized” ou “fully supported” é usado sem evidência.

**Tests**: none
**Gate**: Quick
**Commit**: `docs: prepare technical preview release notes`

### T19: Executar gate final do autor e congelar diff para o Verifier

**What**: Rodar o Build gate, comparar contagem de testes, revisar escopo e deixar o diff pronto para verificação independente.
**Where**: `.specs/features/release-readiness/`, relatório de execução
**Depends on**: T3, T7, T12, T16, T18
**Reuses**: `tasks.md`, `spec.md`, CI output, readiness checklist
**Requirement**: RR-15, RR-18

**Done when**:

- [ ] Todos os gates aplicáveis passam ou têm blocker explícito.
- [ ] A contagem de testes não diminuiu.
- [ ] O diff contém somente escopo da iniciativa.
- [ ] O orquestrador registra o range de commits e despacha um Verifier fresco.

**Tests**: full/build
**Gate**: Build
**Commit**: `chore: freeze release readiness evidence`

## Independent Verifier Contract

Após T19, despachar automaticamente um agente que não participou da autoria.
Ele deve:

1. Ler novamente `spec.md`, `design.md`, `tasks.md` e o diff.
2. Mapear RR-01–RR-18 com evidence-or-zero (`file:line` + assertion ou evidência manual).
3. Confirmar que a asserção verifica o valor/estado definido pelo AC, não apenas que uma chamada ocorreu.
4. Injetar 1–3 mutações comportamentais em scratch state e confirmar que os testes as matam.
5. Escrever `.specs/features/release-readiness/validation.md` com PASS/FAIL, gaps ranqueados, gate, sensor e UAT.
6. Criar tarefas de correção para sobreviventes/gaps; limitar o ciclo fix → reverify a três iterações.
7. Registrar lessons somente se `validation.md` tiver AC gap, surviving mutant, precision gap, SPEC_DEVIATION ou gate failure.

## Phase-Definition Cross-Check

| Task | Declared dependency | Diagram path | Result |
| --- | --- | --- | --- |
| T1 | None | Phase 1 start | ✅ |
| T2 | T1 | T1 → T2 | ✅ |
| T3 | T2 | T2 → T3 | ✅ |
| T4 | None | Phase 2 start | ✅ |
| T5 | T4 | T4 → T5 | ✅ |
| T6 | T5 | T5 → T6 | ✅ |
| T7 | T5 | T5 → T7 | ✅ |
| T8 | T6 | Phase 3 entry from T6 → T8 | ✅ |
| T9 | T8 | T8 → T9 | ✅ |
| T10 | T8 | T8 → T10 | ✅ |
| T11 | T8 | T8 → T11 | ✅ |
| T12 | T9, T10, T11 | T9/T10/T11 → T12 | ✅ |
| T13 | T3 | Phase 4 entry from T3 → T13 | ✅ |
| T14 | T13 | T13 → T14 | ✅ |
| T15 | T13, T14 | T13/T14 → T15 | ✅ |
| T16 | T15 | T15 → T16 | ✅ |
| T17 | T12, T16 | T12/T16 → T17 | ✅ |
| T18 | T17 | T17 → T18 | ✅ |
| T19 | T3, T7, T12, T16, T18 | all required close paths → T19 | ✅ |

## Test Co-location Validation

| Task group | Declared tests | Matrix row | Co-located? | Result |
| --- | --- | --- | --- | --- |
| T1–T3 | shell/build or none + Build gate | Scripts / Markdown | Yes; gate in same task | ✅ |
| T4–T7 | none + Quick gate | Markdown/config | Yes; no artificial unit tests | ✅ |
| T8 | none + Quick gate | Hardware evidence | Yes; sanitized example is fixture | ✅ |
| T9 | shell/build | Scripts de relatório | Yes; valid/invalid fixtures in task | ✅ |
| T10 | unit/integration | Replay isolation | Yes; tests modificados junto do comportamento | ✅ |
| T11 | unit/integration | Permission/fallback | Yes; testes modificados junto do comportamento | ✅ |
| T12 | manual hardware | Hardware físico | Yes; report is the evidence artifact | ✅ |
| T13–T16 | shell/build or manual release | Signing/distribution | Yes; package/preflight evidence in task | ✅ |
| T17–T19 | none/full/build | Release state and traceability | Yes; final gate before Verifier | ✅ |

## Agent Contracts

### Batch 1 worker — CI + public contract

- Recebe T1–T7, `spec.md`, `design.md` e este arquivo.
- Não altera recognizers, persistence ou private bridge.
- Reporta commits atômicos, comandos e contagem de testes.
- Para em qualquer gate vermelho; não entrega “quase pronto”.

### Batch 2 worker — QA + hardware

- Recebe T8–T12 somente após Batch 1 verde.
- Pode preparar scripts/fixtures e executar replay automaticamente.
- A sessão física exige autorização e presença do usuário/hardware; ausência vira `NOT-RUN`, nunca evidência inventada.
- Não commita raw frames, serial, TCC ou dados pessoais.

### Batch 3 worker — distribution + close

- Recebe T13–T19 somente após Batch 2 concluído.
- Usa `packaging-notarization` e `signing-entitlements` para separar dry-run de release real.
- Nunca solicita, grava ou publica segredos Apple.
- Entrega o diff congelado ao Verifier.

### Verifier

- Autor diferente dos workers.
- Read-only no working tree real; mutações somente em scratch.
- Veredito obrigatório: PASS, FAIL ou BLOCKED, sempre com evidência.
