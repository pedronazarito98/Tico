# Evidência — experiências contextuais

## Escopo e baseline

Em 19–20/10/2026, foram implementadas as ideias 2, 3, 5 e 6: conteúdo,
aprendizado, cenas com layouts e rotinas de telas. Mudanças do criador visual já
existiam no worktree e foram preservadas; o inventário desta tarefa está em
`files.md`. Não foram criados testes, mocks, fixtures ou dependências.

Baseline em 19/10:

- `swift build --disable-sandbox --product Tico`: PASS, 8,23 s.
- `swift test --disable-sandbox -q`: PASS, 128 testes, zero falhas, 1,368 s.
- Fontes consultadas: README, Package.swift, CONTRIBUTING, AGENTS aplicáveis,
  specs de arquitetura/V2, modelos, executor, serviços de plataforma,
  composition root, views envolvidas e fronteiras de persistência.
- Nenhum dado pessoal, credencial, histórico de uso ou cache de conteúdo foi lido.

## Verificações executadas na integração

| Verificação | Resultado observado |
| --- | --- |
| `git diff --check` | PASS nas integrações, inclusive após o ajuste final de mensagens |
| Build SwiftPM do produto Tico | PASS nas integrações |
| Suíte Swift existente | PASS, 128 testes, zero falhas |
| Gate `TICO_CODESIGN_IDENTITY=- TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package` | PASS em 20/10 nas duas passagens; revisão final concluída após 09:37 |
| Sintaxe dos scripts canônicos (`bash -n`, pelo gate) | PASS |
| Target fino Xcode, Debug e archive Release arm64 + x86_64 | PASS; assinatura estrita e metadados verificados |
| Fluxo XCUITest existente em dados isolados | PASS |
| Suíte existente de segurança, execução separada | PASS, 8 testes, zero falhas |
| Pacotes locais ZIP e DMG | PASS, assinatura ad hoc, plist, montagem e checksum do DMG |
| Preflight local de ZIP/DMG | PASS como desenvolvimento local; não equivale a distribuição notarizada |

A primeira passagem completa executou os 128 testes em 1,237 s. Depois dela,
foram integrados o diagnóstico local do painel de conteúdo, textos de orientação
e as correções da revisão final descritas abaixo. O gate completo foi repetido
sobre essa revisão: build SwiftPM em 2,70 s; Xcode e XCUITest PASS; 128 testes sem
falhas em 1,249 s; oito testes de segurança sem falhas em 0,080 s; ZIP, DMG e
preflight local PASS. Os pacotes em `dist` correspondem a essa passagem final.

Não foi executado um linter Swift separado. Os testes existentes cobrem regressões
anteriores; eles não constituem uma suíte específica para todas as combinações das
quatro funcionalidades novas. Nenhum assertion foi removido ou enfraquecido.

## Observação nativa com REA e interação isolada

Foi aplicada a skill `reverse-engineer-anything`: leitura das fontes completas,
seguida de observação nativa de uma sessão de desenvolvimento. A tentativa inicial
com o executável SwiftPM direto foi BLOCKED por `process-identity-unavailable`.
Um bundle temporário ad hoc aberto pelo LaunchServices forneceu identidade válida
para observação pelo REA.

A sessão usou `--ui-testing`, diretório e preferências exclusivos, execução real
bloqueada, nenhum banco pessoal e nenhuma concessão de TCC. O REA foi limitado
ao processo e à janela escolhidos. A interação subsequente pelo CUA usou o mesmo
bundle. A sessão e a conexão REA foram encerradas ao terminar.

Observações reais nessa compilação intermediária:

- Página Cenas, editor, catálogo de ação de conteúdo e seus controles acessíveis.
- Salvamento de uma cena com ação de conteúdo e de uma rotina inativa por sugestão.
- Captura de layout recusada com a mensagem de indisponibilidade durante validação
  isolada, sem consultar janelas pessoais.
- Painel de conteúdo com Texto, Link e Arquivos; rejeição de `file:///tmp/example`
  como link não HTTP/HTTPS; limpar e fechar funcionaram.
- Objetivo de aprendizado iniciado em 0/5 para uma regra habilitada na biblioteca
  isolada. Nenhuma automação foi executada e nenhum progresso real foi alegado.
- Aparência clara observada. VoiceOver permanece NOT-RUN.

Identificadores de evidência do REA:

| Estado | Evidência |
| --- | --- |
| Janela inicial | `ev_ce131e00ceb4b5b0cb504b61835dff75eec52227ba08748184663dbb24b29668` |
| Cenas | `ev_ceae2d70016807ccae8609e67fde13f4df09eb71aaacb27d2a3364c9a38c12ff` |
| Captura bloqueada em modo isolado | `ev_1ea60af7ca09360fa4479ff52b3a656c503d7da417c4a5a6cd428477bb0cfccf` |
| Editor de conteúdo | `ev_592c6f3afd1643360f0a0dceb422c9ab186f740d27525edcb311474b25252843` |
| Cena salva | `ev_d8798739339f6fa878d3eab61eb05f1ffd1a058ce7bfb0cc0bb994abdd6e8aa0` |

Essa sessão antecedeu os ajustes finais de revisão do layout em duas fases,
reserva de execução, revisão do aprendizado e diagnóstico local do painel. Ela
comprova os estados listados, sem substituir UAT desses fluxos finais.

Após o último gate, o `dist/Tico.app` final foi aberto em outra sessão isolada com
`--ui-testing --ui-testing-dark`. O CUA confirmou visualmente a página Cenas, a
seção de rotinas, o editor e o texto atualizado que explica a ordem das ações e do
layout. A tentativa de captura foi novamente recusada pelo modo isolado. Cancelar
o editor e encerrar o aplicativo funcionaram; a ausência do processo dessa sessão
foi conferida. A aparência escura está observada nesses estados; os demais painéis,
contraste medido e VoiceOver não foram homologados por essa conferência.

## Revisão de implementação

A revisão final encontrou e corrigiu três casos concretos:

- O término de uma sessão contínua agora emite conclusão tipada para aprendizado,
  após atualização bem-sucedida e commit. Regra, revisão, contexto e curva pertencem
  à mesma sessão; cancelamento ou falha não dão crédito. A combinação legada de
  ação contínua com outras etapas/layout recusa objetivo com explicação.
- A rotina em andamento retém seu próprio handle de Task e token de conclusão.
  Bloqueio, repouso, mudança de topologia, suspensão ou configuração invalidada
  cancelam esse handle sem atingir uma execução nova com o mesmo workflowID.
- `.singleWindow` não reutiliza captura quando há ambiguidade, nem permite
  contorná-la pelo picker. O inventário é revalidado antes de aplicar cada slot,
  exigindo o mesmo processo e handle exato. Não existe atomicidade do macOS entre
  a última leitura de Acessibilidade e sua escrita.

A rodada de aprendizado/rotinas também executou 27 testes existentes pertinentes
(12 `AutomationAndProfilesTests` e 15 `ShortcutStoreTests`), sem falhas, antes da
integração final. A mudança de cenas passou por parse e build sem ações AX reais.

| Área | Fato verificado nas fontes | Limite da evidência |
| --- | --- | --- |
| Conteúdo | Entrada não Codable, limites, seleção explícita, foco/PID revalidados, temporários privados e cancelamento do subprocesso | Seleção e app Atalhos reais NOT-RUN |
| Aprendizado | Origem tipada, sucesso real para progresso, revisão da regra, um objetivo e intervalos de dicas | Uso cotidiano/gesto físico NOT-RUN |
| Cenas | Reserva antes de efeitos; ações precedem revisão; prazo cobre espera; recuperação por referências exatas e leitura de retorno | AX e movimentação real de janelas NOT-RUN |
| Rotinas | Baseline, debounce, suspensão, intenção consumida uma vez e elegibilidade automática revalidada | Monitores físicos e sleep/wake NOT-RUN |
| Persistência | Documento versão 7; arquivos próprios limitados e atômicos; arquivos inválidos não sobrescritos silenciosamente | Migração de dados pessoais NOT-RUN |

## Validação manual restante

Usar apenas conteúdo descartável e janelas escolhidas para a validação:

1. **Conteúdo:** pesquisa com texto e URL; envio de arquivo regular ao Atalhos;
   seleção explícita em aplicativo compatível; recusa de campo protegido, troca de
   foco, diretório, symlink e excesso de tamanho; cancelar/fechar durante execução.
2. **Aprendizado:** começar um objetivo, executar pelo acionamento real, confirmar
   incremento somente após sucesso e ausência de crédito em prática/replay; testar
   adiar/desligar dicas e editar/pausar a regra durante o objetivo.
3. **Cenas:** capturar duas janelas, abrir um aplicativo pela cena, revisar
   Agora/Depois, resolver duas janelas do mesmo aplicativo, aplicar e restaurar.
   Repetir com janela fechada, alteração manual, timeout, cancelamento e tentativa
   de executar outra cena com recuperação pendente. Confirmar que as ações
   anteriores à revisão não são repetidas nem desfeitas ao cancelar o layout.
4. **Telas:** conectar, desconectar e trocar a tela principal; confirmar uma única
   sugestão, escolha entre rotinas concorrentes e modo automático somente quando
   explicitamente configurado. Validar pausa, gravação, prática, lock e sleep/wake.
5. **Acessibilidade e apresentação:** teclado, foco, VoiceOver, claro/escuro,
   Reduzir Movimento e telas com escalas diferentes.

## Entrega

Pacotes locais de desenvolvimento: `dist/Tico.app`, `dist/Tico.zip` e
`dist/Tico.dmg`. A identidade pública e a versão do projeto foram preservadas.
Assinatura Developer ID, notarização, staple, execução em máquina limpa e release
pública são NOT-RUN. O archive Xcode Release universal e o pacote SwiftPM local
são artefatos distintos; a arquitetura do pacote local segue o host.

Nenhum commit, push, PR, instalação em Applications ou publicação foi realizado.
