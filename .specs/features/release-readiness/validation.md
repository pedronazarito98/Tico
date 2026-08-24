# Release Readiness Validation — prontidão local sem Developer ID

**Atualizado**: 2026-08-24  
**Spec**: `.specs/features/release-readiness/spec.md`  
**Branch**: `feat/complete-local-release-readiness`  
**Pull request**: [#8](https://github.com/pedronazarito98/Tico/pull/8)  
**Evidência funcional verde**: run [32762550398](https://github.com/pedronazarito98/Tico/actions/runs/32762550398), commit `b393a400`  
**Veredito**: **PASS para desenvolvimento, pacote ad hoc e preparação de beta interna; validação física permanece parcial**

## Escopo do veredito

Esta rodada não usa Developer ID como requisito. Developer ID, notarização,
staple, Gatekeeper e máquina limpa continuam necessários somente para uma
futura distribuição binária pública.

O veredito `PASS` significa que a implementação, os hosts SwiftPM/Xcode, a suíte,
o XCUITest isolado, as regressões de segurança e os pacotes locais passaram no
gate remoto. Ele não significa compatibilidade física completa nem estabilidade
diária comprovada.

## Alterações validadas

| Área | Evidência | Resultado |
| --- | --- | --- |
| Permissões no composition root | Estado de concessão/revogação lido somente do diretório temporário `TicoUITests-*`; ausência ou JSON inválido permanece restritivo | `PASS` |
| Captura após revogação | `CaptureCoordinator` encerra event tap e observação; `AppController` encerra também a automação | `PASS` |
| Retorno ao primeiro plano | Janela, atualização manual e barra de menus reconciliam o estado observado | `PASS` |
| Toolbar e menu | Quando não há autorização, exibem ação de configurar e navegam para Permissões | `PASS` |
| XCUITest de regra | Cria regra desativada, relança e confirma persistência isolada | `PASS` |
| XCUITest de permissões | Valida estado restrito, concessão e revogação simuladas sem solicitar TCC | `PASS` |
| Matriz manual | Gate exige 31 cenários, apenas `PASS`/`FAIL`/`NOT-RUN` e resumo consistente | `PASS` |
| Diagnóstico de UI test | Falha preserva `.xcresult` durante a execução e imprime resultados estruturados | `PASS` |
| Workflows obsoletos | `concurrency` cancela runs anteriores do mesmo PR/ref | `PASS` |

## Gate remoto observado

O run `32762550398` foi executado no runner `macos-26` e concluiu o job
`Build, test, and package (macOS 26)` com sucesso. Os steps de checkout,
relatório de toolchain, gate compartilhado e resumo também terminaram com
`success`.

O gate executado pelo workflow inclui:

```sh
./script/ci_verify.sh --package
```

Cobertura declarada pelo próprio script e workflow:

- validação dos scripts shell;
- consistência da matriz manual;
- build do produto SwiftPM `Tico`;
- build e verificação do App Target Xcode;
- Archive Release universal;
- XCUITest end-to-end isolado;
- suíte Swift completa;
- `SecurityRegressionTests`;
- ZIP e DMG ad hoc;
- preflight estrutural dos dois artefatos.

O HEAD final do PR deve permanecer verde. Runs intermediários vermelhos foram
usados para corrigir os novos seletores XCUITest e não tiveram assertions
removidas ou enfraquecidas.

## Matriz manual preservada

A matriz continua com:

| Resultado | Quantidade |
| --- | ---: |
| `PASS` | 11 |
| `FAIL` | 0 |
| `NOT-RUN` | 20 |

A cobertura automatizada adicionada foi registrada nas observações, mas não
promoveu os cenários que dependem do sistema ou de hardware.

## Validação ainda necessária

| Cenário | Estado | Motivo |
| --- | --- | --- |
| Reduzir Transparência, Reduzir Movimento e Aumentar Contraste | `NOT-RUN` | Exige inspeção interativa do mesmo app |
| Navegação completa por teclado e VoiceOver | `NOT-RUN` | Árvore AX automatizada não substitui uso do leitor de tela |
| Revogação no TCC real | `NOT-RUN` | Estado simulado prova o app, não o banco de permissões do macOS |
| Teclado/mouse durante captura real | `NOT-RUN` | Exige interação com outro aplicativo |
| Tap, hold, swipes, pinça e rotação | `NOT-RUN` | Exigem contatos físicos no trackpad |
| Sleep/wake | `NOT-RUN` | Não é exercitado pelo CI |
| Uso normal por 15 minutos e falsos positivos | `NOT-RUN` | Exige sessão humana observável |
| Atualização preservando dados reais | `NOT-RUN` | XCUITest cobre relançamento, não migração entre builds |
| Magic Trackpad | `NOT-RUN` | Hardware não disponível |

## Critério para a próxima rodada

1. Gerar o pacote uma única vez com o gate canônico.
2. Registrar o SHA-256 de `dist/Tico.zip` sem caminho pessoal.
3. Usar exatamente o mesmo `Tico.app` durante toda a sessão.
4. Não recompilar nem executar `tccutil reset` entre cenários.
5. Atualizar apenas linhas realmente exercitadas da matriz.
6. Considerar qualquer `FAIL` em TCC, captura avançada, sleep/wake ou
   persistência como bloqueador operacional.

## Limites e bloqueios externos

- **PASS**: implementação e validação automatizada da prontidão local.
- **NOT-RUN**: trackpad físico, TCC real, VoiceOver, sleep/wake e atualização
  real nesta rodada.
- **BLOCKED**: proteção obrigatória da `main` não foi aplicada porque a conexão
  GitHub disponível não expõe mutação de branch protection/rulesets.
- **Fora do escopo atual**: Developer ID, notarização, staple, Gatekeeper e
  máquina limpa.
