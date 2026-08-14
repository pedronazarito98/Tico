# Shell Liquid Glass do macOS 26 — Validation

**Date**: 2026-08-14
**Spec**: `.specs/features/macos-26-liquid-glass-shell/spec.md`
**Diff range**: `bcb1a2f..e22f76e` (`45e0c0c`, `c3293ab`, `e22f76e`)
**Revalidation delta**: `c3293ab..e22f76e`
**Verifier**: independent sub-agent (author != verifier)
**Verdict**: **PASS**

---

## Task Completion

Não há `tasks.md` para esta feature. A conclusão foi rederivada dos commits,
da spec LG-01..LG-06, das assertions atuais, do gate executado e do sensor.

| Unidade | Status | Notas |
| --- | --- | --- |
| Implementação `45e0c0c` | Done | Shell, Visão geral e Laboratório Liquid Glass. |
| Spec e UAT `c3293ab` | Done | Spec LG-01..LG-06 e matriz sanitizada. |
| Cobertura `e22f76e` | Done | Três testes para busca/reseleção, estados de captura e árvore AX. |
| Revalidação independente | Done | Gate PASS e 3/3 mutantes mortos. |

---

## Spec-Anchored Acceptance Criteria

| Critério | Resultado definido pela spec | `file:line` + assertion/evidência | Resultado |
| --- | --- | --- | --- |
| LG-01 — Shell e busca | Selecionar seção/regra, inclusive a atual, encerra a busca, restaura a sidebar e preserva o destino. | `Tests/TicoTests/MacOS26ShellBehaviorTests.swift:11-23` — `XCTAssertEqual(selection.selectedSection, .laboratory)`, `XCTAssertFalse(selection.changesDestination)`, `XCTAssertEqual(selection.searchText, "")` e `XCTAssertTrue(selection.dismissesSearch)`; `Sources/Tico/Views/ContentView.swift:331-344` consome a decisão; UI26-08 `PASS` em `outputs/macos-26-manual-matrix.md:65`. | PASS |
| LG-02 — Controle de captura | Quatro estados distintos, Liquid Glass, Reduzir Movimento e ação encaminhada sem duplicar domínio. | `Tests/TicoTests/MacOS26ShellBehaviorTests.swift:25-58` — quatro `XCTAssertEqual` exigem `.permissionRequired`, `.paused`, `.active` e `.limited`; `Sources/Tico/Views/Components/CaptureGlassControl.swift:119-147` é a seam usada pela view; `:17-35` desativa animação sob Reduzir Movimento; `:127-132` encaminha a ação; UI26-09 `PASS` em `outputs/macos-26-manual-matrix.md:66`. | PASS |
| LG-03 — Visão geral contínua | Identidade, ações, métricas e atividade em fluxo contínuo, com contraste, hierarquia e atalhos preservados. | `Sources/Tico/Views/OverviewView.swift:17-37` organiza o fluxo; `:40-99` integra identidade/ações; `:101-157` mantém métricas responsivas; `Sources/Tico/Views/ContentView.swift:45-72` preserva toolbar; UI26-01/02 `PASS` em `outputs/macos-26-manual-matrix.md:58-59`. Critério visual coberto pela UAT exigida pela spec, não reivindicado como XCTest. | PASS |
| LG-04 — Laboratório imersivo | Superfície contínua, HUD Liquid Glass e métricas/diagnóstico legíveis. | `Sources/Tico/Views/TrackpadLaboratoryView.swift:29-95` compõe canvas/camadas/HUD; `Sources/Tico/Views/Components/TrackpadLaboratoryHUD.swift:15-58` contém modo, captura e sessão; `Sources/Tico/Views/TrackpadLiveView.swift:8-43` sobrepõe métricas e diagnóstico no canvas; UI26-01/10 `PASS` em `outputs/macos-26-manual-matrix.md:58` e `:67`. Critério visual coberto pela UAT exigida pela spec, não reivindicado como XCTest. | PASS |
| LG-05 — Acessibilidade | Controles preservam rótulos/valores e ícones decorativos não aparecem como ações ou nomes falsos. | `Tests/TicoTests/MacOS26ShellBehaviorTests.swift:60-104` materializa uma árvore AX real, comprova o marcador com `XCTAssertTrue` e ausência do papel `image` com `XCTAssertFalse`; `Sources/Tico/Views/Components/DiagnosticStatusIcon.swift:3-10` é o componente exercitado e `Sources/Tico/Views/TrackpadLiveView.swift:85-90` o integra; UI26-10 `PASS` em `outputs/macos-26-manual-matrix.md:67`. | PASS |
| LG-06 — Integração e plataforma | Hosts SwiftPM/Xcode em macOS 26, suíte/segurança/pacotes ad hoc aprovados e gates externos separados. | `Package.swift:5-12` declara `.macOS("26.0")`; `Tico.xcodeproj/project.pbxproj:154` e `:164` fixam 26.0; gate desta revalidação aprovou SwiftPM, Xcode Debug/Release universal, 128/128 testes, 8/8 regressões e ZIP/DMG ad hoc. | PASS |

**Status**: 6/6 critérios correspondem aos outcomes da spec; 0 gaps de
precisão. LG-03/LG-04 continuam corretamente ancorados na UAT visual exigida
pela própria spec, sem transformar build ou XCTest em alegação visual.

---

## Targeted Test Check

- **Comando**: `swift test --disable-sandbox --filter MacOS26ShellBehaviorTests`.
- **Resultado**: 3 passed, 0 failed, 0 skipped.
- **Busca/reseleção**: PASS.
- **Estados permission/paused/active/limited**: PASS.
- **Árvore AX do ícone decorativo**: PASS.

As assertions miram valores definidos pela spec, e não somente a existência de
uma chamada. O teste AX também exige que a árvore esteja materializada antes de
afirmar a ausência do ícone, evitando falso verde por árvore vazia.

---

## Discrimination Sensor

As três mutações foram aplicadas isoladamente em cópias de `e22f76e` criadas
por `git archive` sob `/private/tmp`. Cada cópia executou somente o teste
correspondente; nenhuma mutação tocou o working tree real. A raiz temporária foi
movida para a Lixeira ao final.

| Mutação | Falha injetada | Teste discriminante | Evidência de morte | Resultado |
| --- | --- | --- | --- | --- |
| M1 | Re-selecionar o destino atual retorna sem limpar/encerrar a busca. | `testReselectingCurrentSectionClearsSearchAndPreservesDestination` | Exit 1; `XCTUnwrap failed: expected non-nil value of type ShellNavigationSelection`. | KILLED |
| M2 | Classificação `.active`/`.limited` invertida. | `testCaptureGlassStateDistinguishesPermissionPausedActiveAndLimitedModes` | Exit 1; duas falhas `XCTAssertEqual`: `limited != active` e `active != limited`. | KILLED |
| M3 | `DiagnosticStatusIcon` usa `.accessibilityHidden(false)`. | `testDiagnosticIconIsExcludedFromTheRenderedAccessibilityTree` | Exit 1; `XCTAssertFalse failed` porque o papel AX `image` reapareceu. | KILLED |

**Sensor depth**: lightweight, três mutações comportamentais direcionadas.

**Resultado**: 3/3 killed, 0 survived — **PASS**.

---

## Interactive UAT Results

O Verifier não repetiu nem ampliou a sessão interativa. A revalidação preserva
a matriz sanitizada do app final e somente as afirmações nela registradas.

| Cenário | Resultado | Limite da evidência |
| --- | --- | --- |
| UI26-01/02 | PASS | Tamanho mínimo e aparências clara/escura; não prova Reduzir Transparência. |
| UI26-08 | PASS | Re-seleção de Laboratório/regra e troca para Visão geral restauraram a sidebar. |
| UI26-09 | PASS | Permissão, pausa e atividade foram observadas; fallback foi identificado separadamente. |
| UI26-10 | PASS | HUD e árvore do diagnóstico foram inspecionados. |
| UI26-03/04/07 | NOT-RUN | Reduzir Transparência, Reduzir Movimento/Aumentar Contraste e navegação completa por teclado/VoiceOver não foram exercitados. |
| Trackpad físico e notarização | NOT-RUN | Nenhum resultado inferido de build, teste ou replay. |

A matriz permanece coerente: 11 `PASS`, 0 `FAIL` e 20 `NOT-RUN`, com trackpad
físico não exercitado e assinatura ad hoc.

---

## Gate Check

- **Diff check**: `git diff --check c3293ab..e22f76e` — PASS.
- **Gate**: `TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package` — PASS, exit 0.
- **Hosts**: SwiftPM PASS; Xcode Debug PASS; Release archive universal `arm64 + x86_64`, mínimo 26.0 e Hardened Runtime PASS.
- **Testes**: 128 passed, 0 failed, 0 skipped.
- **Regressões de segurança**: 8 passed, 0 failed, 0 skipped.
- **Pacotes**: APP, ZIP e DMG ad hoc verificados; checksum do DMG válido.
- **Contagem**: 125 métodos XCTest antes da cobertura; 128 no commit atual; delta +3.
- **Notarização/staple/clean-machine**: NOT-RUN (`not-attempted`, `not-validated`, `not-run` no preflight).
- **Hardware físico/TCC completo**: NOT-RUN; o gate automatizado não os exercitou.

---

## Code Quality

| Princípio | Status | Evidência |
| --- | --- | --- |
| Escopo mínimo | PASS | Delta limitado às três seams de comportamento e ao arquivo de testes autorizado. |
| Mudanças cirúrgicas | PASS | Sem alterações em domínio, persistência, captura ou execução de regras. |
| Sem abstrações futuras | PASS | `ShellNavigationSelection`, `CaptureGlassState.resolve` e `DiagnosticStatusIcon` têm consumidor real e teste correspondente. |
| Padrões das Views | PASS | Estado/decisão extraídos do `body`; valores e ações continuam estreitos. |
| Integridade dos testes | PASS | Três testes novos; nenhum teste removido, pulado ou enfraquecido. |
| Spec-anchored outcomes | PASS | Assertions exatas para LG-01, LG-02 e LG-05; LG-03/LG-04 permanecem UAT visual explícita. |
| Sensor discriminante | PASS | 3/3 mutantes mortos pelos testes correspondentes. |
| Diretrizes | PASS | `AGENTS.md`, `Sources/Tico/Views/AGENTS.md` e `Tests/TicoTests/AGENTS.md` respeitados. |

---

## Edge Cases and Boundaries

- Re-seleção do destino atual: coberta por assertion e mutação morta.
- Fallback limitado versus captura avançada: ambos cobertos e mutação morta.
- Árvore AX vazia: o teste exige primeiro o marcador acessível, depois verifica
  a ausência da imagem decorativa.
- Reduzir Movimento tem implementação explícita; UI26-04 continua `NOT-RUN`.
- Reduzir Transparência e navegação completa por VoiceOver continuam `NOT-RUN`.
- Trackpad físico, sleep/wake, Magic Trackpad, Developer ID, notarização,
  Gatekeeper e clean machine não são comprovados por este relatório.

---

## Requirement Traceability Update

O `spec.md` não foi alterado porque esta tarefa autorizou exclusivamente a
atualização de `validation.md`.

| Requirement | Resultado |
| --- | --- |
| LG-01 | Verified — assertion exata + mutante morto + UAT |
| LG-02 | Verified — quatro estados + mutante morto + UAT |
| LG-03 | Verified — código + UAT visual sanitizada |
| LG-04 | Verified — código + UAT visual sanitizada |
| LG-05 | Verified — árvore AX real + mutante morto + UAT |
| LG-06 | Verified — gate canônico completo |

---

## Summary

**Overall**: **PASS — pronto para encerrar a verificação independente**.

**Spec-anchored check**: 6/6 outcomes sustentados, 0 gaps de precisão.

**Gate**: 128/128 testes, 8/8 regressões, hosts SwiftPM/Xcode e ZIP/DMG ad hoc
aprovados.

**Sensor**: 3/3 killed, 0 survived.

**Limites preservados**: UAT UI26-03/04/07, hardware físico, Developer ID,
notarização, Gatekeeper e clean-machine continuam `NOT-RUN`; o PASS não amplia
essas alegações.

**Lessons**: clean PASS; nenhuma nova lesson foi registrada.
