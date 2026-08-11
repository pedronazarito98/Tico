# Release Readiness Validation — atualização pós-merge

**Atualizado**: 2026-08-11
**Spec**: `.specs/features/release-readiness/spec.md`
**Base verificada**: `main` / `1a7593cd12f4363e28224e817fb96d1568b3f550`
**PR integrado**: [#3](https://github.com/pedronazarito98/Tico/pull/3)
**Natureza**: refresh de evidências; não substitui uma nova execução independente do Verifier
**Veredito**: **BLOCKED — preview técnico saudável; release binária não pronta**

Esta atualização corrige o snapshot de 2026-07-26 com o estado pós-merge real.
Ela mantém `PASS`, `NOT-RUN` e `BLOCKED` separados: build, testes e CI verde não
provam hardware físico, TCC em máquina real, notarização ou Gatekeeper.

## Estado pós-merge

| Evidência | Resultado |
| --- | --- |
| Branch local | `main`, worktree limpo antes desta edição documental |
| `HEAD` / `origin/main` | `1a7593cd12f4363e28224e817fb96d1568b3f550` |
| PR #3 | merged em `2026-08-11`; não é mais draft |
| CI do PR | PASS — [run 31486597406](https://github.com/pedronazarito98/Tico/actions/runs/31486597406), job `Build, test, and package` concluído |
| CI do merge | PASS — [run 31487484224](https://github.com/pedronazarito98/Tico/actions/runs/31487484224), job `Build, test, and package` concluído |
| `git diff --check` no HEAD | PASS |

Os dois runs remotos executaram o workflow `macOS verification` em `macos-14`.
O run de merge fecha a evidência remota que estava ausente no relatório anterior.

## Gate local atual

**Comando executado**:

```sh
AIRSHORTCUT_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package
```

| Check | Resultado atual |
| --- | --- |
| Validação de shell | PASS — `bash -n` para os cinco scripts do gate |
| Build | PASS — produto SwiftPM `AirShortcut` |
| Suíte Swift | PASS — 125 testes, 0 falhas |
| `SecurityRegressionTests` | PASS — 8 testes, 0 falhas |
| Package | PASS — `dist/Tico.zip`; app extraído passou `codesign --verify --deep --strict` e identidade Tico/AirShortcut |
| Hardware físico | NOT-RUN pelo gate automatizado |
| Notarização | NOT-RUN pelo gate automatizado |

O ambiente local reportou Swift 6.3.3 e Xcode 26.6. O SwiftPM emitiu apenas
warnings de arquivos `AGENTS.md` não declarados como resources; o comando
terminou com exit code 0.

## Preflight do artefato atual

**Comando executado**:

```sh
./script/release_preflight.sh dist/Tico.zip
```

Resultado observado:

- identidade pública: `Tico`;
- executável técnico: `AirShortcut`;
- bundle identifier: `com.pedronazarito.AirShortcut`;
- assinatura profunda estrita: `PASS`;
- modo de assinatura: `ad-hoc/development`;
- Hardened Runtime: `not-confirmed`;
- entitlements: `none`;
- notarização: `not-attempted`;
- staple: `not-validated`;
- execução em máquina limpa: `not-run`;
- decisão: somente desenvolvimento/QA; nenhuma reivindicação de Gatekeeper ou notarização.

## Tasks

| Tasks | Estado pós-merge | Evidência |
| --- | --- | --- |
| T1–T3 | Parcial | Gate local e runs reais passam; injeção de falha controlada no CI continua `NOT-RUN`. |
| T4–T7 | Concluído para preview | `LICENSE` MIT, README, contribuição, segurança, QA e distribuição estão presentes e coerentes. |
| T8–T11 | Concluído no escopo automatizado | Template/validador, replay, permissões e fallback têm cobertura automatizada. |
| T12 | `BLOCKED` | Não existe relatório físico sanitizado preenchido no checkout atual. |
| T13–T15 | Concluído para ad hoc | ZIP atual passa preflight e é rotulado como desenvolvimento. |
| T16 | `BLOCKED` | Não há Developer ID, notarização aceita, staple, Gatekeeper ou máquina limpa. |
| T17–T19 | Parcial | Evidência e lições históricas existem; este refresh não é um novo Verifier independente. |

## Matriz RR-01–RR-18

| AC | Evidência atual | Resultado |
| --- | --- | --- |
| RR-01 | `.github/workflows/ci.yml:3-23` aciona PR/push em `main`; `script/ci_verify.sh:1-5,39-72` é fail-fast; [run real do PR](https://github.com/pedronazarito98/Tico/actions/runs/31486597406) passou. A execução controlada de uma falha ainda não foi feita. | **BLOCKED** |
| RR-02 | `README.md:50-69` documenta o gate; `script/ci_verify.sh:74-89` imprime contagem e artefatos; execução atual registrou 125 testes e `dist/Tico.zip`. | **PASS** |
| RR-03 | `.github/workflows/ci.yml:25-34` separa cobertura automatizada, física e distribuição; [run de merge](https://github.com/pedronazarito98/Tico/actions/runs/31487484224) concluiu o step de resumo. | **PASS** |
| RR-04 | `README.md:34-48` e `outputs/qa-checklist.md:29-45` usam `⌘6`; não há referência contraditória a `⌘4` nos documentos públicos atuais. | **PASS** |
| RR-05 | `LICENSE:1-20` contém MIT; `README.md:32-48,80-85` declara technical preview, status, fallback e compatibilidade com framework privado; `outputs/distribuicao.md:3-16` mantém a fronteira de distribuição. | **PASS** |
| RR-06 | `SECURITY.md:8-28` direciona vulnerabilidades para fluxo privado e proíbe credenciais, dados pessoais e logs sensíveis públicos. | **PASS** |
| RR-07 | `outputs/hardware-validation/report-template.md:3-26` define o schema, mas não há `report-AAAA-MM-DD.md` preenchido no checkout atual. | **BLOCKED** |
| RR-08 | `Tests/AirShortcutTests/PermissionCoordinatorTests.swift:38-55`, `Tests/AirShortcutTests/SecurityRegressionTests.swift:212-260` e `Tests/AirShortcutTests/TrackpadGestureServiceTests.swift:49-80` cobrem estados negados/fallback; a observação física e o relatório sanitizado continuam ausentes. | **BLOCKED** |
| RR-09 | `Tests/AirShortcutTests/TrackpadLaboratoryPhaseOneTests.swift:190-203` verifica replay em `0.5`, `1.0` e `2.0`, estado do laboratório e log de ações inalterado. | **PASS** |
| RR-10 | `outputs/qa-checklist.md:47-63` e `outputs/trackpad.md:27-31` impedem declarar Magic Trackpad sem teste; `outputs/hardware-validation/report-template.md:5-8` diferencia `NOT-RUN` de aprovação. | **PASS** — política de bloqueio preservada; suporte físico segue bloqueado. |
| RR-11 | `script/ci_verify.sh:55-71` extrai o ZIP, limpa xattrs, verifica assinatura profunda e identidade; o gate local atual passou. | **PASS** |
| RR-12 | `script/release_preflight.sh:48-56,71-90` classifica o pacote atual como `ad-hoc/development` e não reivindica notarização/Gatekeeper. | **PASS** |
| RR-13 | `outputs/distribuicao.md:25-59` e `outputs/qa-checklist.md:74-83` exigem Developer ID, Hardened Runtime, notarização, staple, Gatekeeper e máquina limpa antes de release binária. | **PASS** — contrato documental; execução real continua ausente. |
| RR-14 | `CHANGELOG.md:23-45` registra o preview e suas limitações, mas não há release binária publicada com metadados/evidências do commit atual; `dist/Tico.zip` é ad hoc. | **BLOCKED** |
| RR-15 | O relatório independente histórico em `57fb0ed` mapeou RR-01–RR-18 com evidence-or-zero; este documento atualiza o estado pós-merge, mas não reivindica uma nova rodada independente. | **PASS** — evidência independente histórica preservada. |
| RR-16 | O Verifier histórico registrou três mutações comportamentais mortas (3/3) no snapshot de release-readiness; não foi injetada nova mutação neste refresh documental. | **PASS** — sensor histórico preservado; não é novo resultado do merge. |
| RR-17 | `.specs/LESSONS.md` e `.specs/lessons.json` preservam os gaps de CI, licença, hardware, distribuição e o sinal do sensor anterior. | **PASS** |
| RR-18 | Este relatório mantém o veredito `BLOCKED` e lista os gaps sem promovê-los a `PASS` por causa do CI verde. | **PASS** |

**Status rastreável**: 14/18 PASS; 0/18 FAIL; 4/18 BLOCKED; nenhum falso
`PASS` para hardware físico ou distribuição notarizada.

## Gaps que permanecem

1. **RR-01** — executar uma falha controlada em um PR descartável e preservar o
   run vermelho e o run verde correspondente.
2. **RR-07/RR-08** — executar e sanitizar a matriz física aplicável, incluindo
   permissão negada, fallback e segurança de teclado/mouse.
3. **RR-14/T16** — se houver intenção de distribuir binário, obter Developer ID,
   assinar com Hardened Runtime, notarizar, validar staple/Gatekeeper e testar
   o mesmo ZIP em máquina limpa; não há credenciais fornecidas nesta tarefa.

## Limites da atualização

- Nenhuma sessão interativa ou física foi executada nesta atualização.
- Nenhum teste, mock ou fixture foi criado.
- O pacote `dist/Tico.zip` é local, ad hoc e não deve ser publicado como release
  para usuários finais.
- Os PASS manuais registrados em documentos anteriores continuam classificados
  como informação do responsável pelo produto; não foram reproduzidos pelo agente
  neste handoff.
