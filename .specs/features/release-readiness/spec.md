# Tico Release Readiness Specification

**Status**: Draft — pronta para revisão do usuário antes do Execute
**Feature key**: `release-readiness`
**Baseline**: `main` / commit `27e0650`

## Problem Statement

O Tico já possui a implementação de automação, laboratório, replay,
regras, workflows e correções de segurança. Ainda falta transformar essa
validação local em um processo reprodutível para colaboradores e releases:
CI, documentação pública coerente, evidência física do trackpad e uma trilha
de empacotamento/notarização.

O objetivo deste ciclo é responder, com evidência, se o projeto pode ser
publicado como technical preview e quais condições ainda impedem um release
distribuível. Não é um ciclo para adicionar novas famílias de gestos.

## Goals

- [ ] Fazer cada pull request executar os gates SwiftPM e de empacotamento sem depender de julgamento do agente.
- [ ] Corrigir inconsistências públicas e deixar claras as limitações de API privada, fallback e assinatura.
- [ ] Produzir uma matriz manual sanitizada para trackpad interno, Magic Trackpad e fallback público.
- [ ] Separar claramente artefato ad hoc de desenvolvimento, dry-run de release e binário Developer ID notarizado.
- [ ] Encerrar o ciclo com verificação independente, rastreabilidade AC → teste/evidência e sensor de discriminação.

## Out of Scope

| Feature | Reason |
| --- | --- |
| Novas famílias de gestos ou mudanças no reconhecedor | A implementação existente é a baseline; aumentar o domínio elevaria o risco enquanto a validação ainda está incompleta. |
| Mac App Store | O modo avançado depende de `MultitouchSupport`, execução sem sandbox e automações locais. |
| Backend, conta de usuário ou telemetria remota | O produto é local e a auditoria não identificou ingestão remota. |
| Prometer compatibilidade universal com versões futuras do macOS | A ABI privada pode mudar e precisa ser revalidada por versão. |
| Fazer notarização sem identidade Apple disponível | O plano prepara e verifica o fluxo; credenciais reais pertencem ao proprietário do projeto. |

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Nome do ciclo | `release-readiness` | Descreve o trabalho sem sugerir que o app já é stable. | n |
| Status público antes da matriz física | `technical preview` / `alpha` | A auditoria de código passou, mas hardware, TCC e falso positivo ainda precisam de evidência. | n |
| Atalho oficial do laboratório | `⌘6` | O código atual e o README usam `⌘6`; o checklist antigo usa `⌘4` e deve ser corrigido. | n |
| CI em hosted macOS runner | Executar build/test/replay; nunca fingir hardware físico | CI não deve marcar captura avançada como validada sem hardware. | n |
| Distribuição | Direct distribution com Developer ID, Hardened Runtime e notarização | É o caminho compatível com o modo experimental atual. | n |
| Evidência pública | Markdown/JSON sanitizado, sem frames brutos ou IDs | O repositório é público e o laboratório toca dados locais. | n |
| Falha de captura privada | Manter fallback público explícito e status “não verificado” para recursos ausentes | A ausência da ABI não pode quebrar teclado/mouse nem ser apresentada como sucesso. | n |
| Disponibilidade de hardware | Pelo menos trackpad interno; Magic Trackpad quando disponível | Sem dispositivo externo, registrar `not-run` e não converter em PASS. | n |

**Open questions**: nenhuma necessária para criar o plano. As decisões acima
são defaults explícitos e devem ser confirmadas antes do Execute.

## User Stories

### P1: Maintainer gets a reproducible gate ⭐ MVP

**User Story**: As a maintainer, I want every change to run the same SwiftPM,
security-regression and package checks so that a green branch means the
automated baseline still works.

**Acceptance Criteria**:

1. **RR-01** — WHEN a pull request targets `main` THEN CI SHALL run on macOS and SHALL fail if `swift build`, `swift test`, shell syntax validation, or package verification exits non-zero.
2. **RR-02** — WHEN a developer runs the documented local gate THEN it SHALL use commands equivalent to CI and SHALL report the produced test count and artifact paths.
3. **RR-03** — WHEN a CI job finishes successfully THEN its summary SHALL distinguish automated replay coverage from physical trackpad coverage and SHALL never claim a hardware PASS.

**Independent Test**: Open a pull request with a controlled failing test in a
throwaway branch, confirm the workflow fails, restore the test, and confirm a
clean run produces a verified SwiftPM/package result.

### P1: Public documentation matches behavior

**User Story**: As a user or contributor, I want the repository to state what
works, what is experimental, and how to report security issues so that I do
not mistake a local development build for a supported release.

**Acceptance Criteria**:

1. **RR-04** — WHEN a new contributor reads the README THEN the documented laboratory shortcut SHALL match the executable command (`⌘6`) and the QA checklist SHALL contain no contradictory shortcut.
2. **RR-05** — WHEN the repository is published THEN it SHALL contain a chosen open-source license, a support/status section, and an explicit note that advanced capture uses a private Apple framework.
3. **RR-06** — WHEN a possible vulnerability is reported THEN `SECURITY.md` SHALL direct the reporter to GitHub private vulnerability reporting and SHALL prohibit public disclosure of sensitive local artifacts.

**Independent Test**: Follow the README from a clean checkout and compare
every documented build, shortcut, artifact, permission and limitation with
the source and scripts.

### P1: Physical trackpad evidence is reproducible

**User Story**: As a release reviewer, I want a structured, sanitized hardware
report so that physical behavior is treated as evidence instead of inference
from unit tests.

**Acceptance Criteria**:

1. **RR-07** — WHEN the manual validation session is completed THEN the report SHALL record OS version, device class, capture mode, gesture, expected result, observed result, and PASS/FAIL/NOT-RUN for every matrix row.
2. **RR-08** — WHEN a private capture is unavailable or permission is denied THEN the report SHALL record the capability as unavailable, SHALL show the user-facing explanation, and SHALL verify that keyboard/mouse capture remains safe.
3. **RR-09** — WHEN replay is imported at 0.5×, 1×, or 2× THEN it SHALL update only the laboratory and SHALL produce no rule execution or action log entry.
4. **RR-10** — WHEN the final release gate is evaluated THEN missing tap, hold, four directional swipes, pinch, rotation, sleep/wake, reconnection, fallback, false-positive, or Magic Trackpad evidence SHALL prevent a physical-support PASS rather than being inferred as success.

**Independent Test**: Run the checklist on the available hardware, export a
sanitized report, inspect the required rows, and compare replay action logs
before and after each replay speed.

### P1: Release artifact is honest and verifiable

**User Story**: As a release owner, I want a release preflight that separates
development signing from distribution signing so that users never receive an
artifact described as notarized without proof.

**Acceptance Criteria**:

1. **RR-11** — WHEN `--package` runs THEN it SHALL produce an app and ZIP whose extracted app passes strict deep code-signature verification in a clean temporary directory.
2. **RR-12** — WHEN no Developer ID identity is configured THEN the process SHALL label the result as ad hoc/development and SHALL not claim Gatekeeper acceptance or notarization.
3. **RR-13** — WHEN a Developer ID release is attempted THEN the checklist SHALL require nested signing, Hardened Runtime, notarization acceptance, stapling, `stapler validate`, and clean-machine execution before release approval.
4. **RR-14** — WHEN a release artifact is published THEN its version, commit SHA, signing mode, macOS minimum, known private-API limitation, and verification evidence SHALL be included in release notes.

**Independent Test**: Run the package dry-run without credentials, inspect its
label and signature, then run the release checklist with a real identity only
when the project owner provides one.

### P2: Independent verification closes the loop

**User Story**: As a project owner, I want a fresh verifier to challenge the
tests and evidence so that a green implementation is not accepted based only
on the author’s assumptions.

**Acceptance Criteria**:

1. **RR-15** — WHEN all implementation tasks are committed THEN an independent verifier SHALL map every AC to a test/evidence citation or mark it as a gap.
2. **RR-16** — WHEN the verifier injects one to three behavior-level faults in scratch state THEN each required test SHALL kill its targeted mutant; survivors SHALL become fix tasks.
3. **RR-17** — WHEN validation has a failed AC, surviving mutant, precision gap, or spec deviation THEN a grounded lesson SHALL be recorded through `scripts/lessons.py`; a clean PASS SHALL record no lesson.
4. **RR-18** — WHEN any required AC remains unverified after three fix/re-verify rounds THEN the initiative SHALL be escalated as not ready, never silently marked complete.

**Independent Test**: Run the Verifier from a fresh context against the spec,
diff and tests, inspect `.specs/features/release-readiness/validation.md`, and
confirm the verdict is supported by evidence.

## Implicit-Requirement Dimensions Sweep

| Dimension | Resolution in this scope |
| --- | --- |
| Input validation & bounds | Reuse existing security regression coverage; CI must run it and hardware reports use a fixed matrix. |
| Failure / partial-failure states | CI, permissions, fallback, not-run hardware rows, unsigned/ad hoc release and notarization failure are explicit states. |
| Idempotency / retry / duplicate handling | CI and package checks are repeatable; reports use a stable session identifier and do not overwrite raw local evidence. |
| Auth boundaries & rate limits | N/A because the product has no remote auth or network ingestion in this feature. |
| Concurrency / ordering | CI jobs are ordered by dependencies; physical capture/replay must remain isolated from rule execution. |
| Data lifecycle / expiry | Public evidence is sanitized and bounded; raw recordings remain local and are not committed. |
| Observability | CI summaries, package paths, test counts, app logs and sanitized hardware outcomes are required. |
| External-dependency failure | Private framework unavailable, TCC denied, Developer ID absent and notarization rejected have documented fallback/stop behavior. |
| State-transition integrity | A release cannot move from draft/alpha to ready without all P1 ACs and independent verification. |

## Requirement Traceability

| Requirement | Primary artifact/test |
| --- | --- |
| RR-01–RR-03 | `.github/workflows/ci.yml`, `script/ci_verify.sh`, CI workflow logs |
| RR-04–RR-06 | `README.md`, `outputs/qa-checklist.md`, `LICENSE`, `SECURITY.md` |
| RR-07–RR-10 | `outputs/hardware-validation/`, manual UAT, existing replay/security tests |
| RR-11–RR-14 | `script/build_and_run.sh`, release preflight, `outputs/signing-and-distribution.md`, release notes |
| RR-15–RR-18 | `.specs/features/release-readiness/validation.md`, Verifier evidence and lessons store |
