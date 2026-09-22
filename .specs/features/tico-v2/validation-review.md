# Validação independente — Tico V2

Data: 16/09/2026. Verificador independente do implementador.

**Veredito final: PARTIAL — revisão estática concluída, cinco achados corrigidos; validação executável incompleta.** Os três builds independentes passaram. A última conferência não deixou achados de código abertos entre F1–F5. A suíte está BLOCKED pelo ambiente, e sensor/hardware/UAT deste verificador estão NOT-RUN. Isso não equivale a aprovação integral da V2.

Escopo: working diff e arquivos novos sobre `2f3c17933594de5644c7c88e074e84b5d0d86b83`, na cópia isolada `tico-v2-review-enxesvev/checkout`, incluindo duas rodadas de correções sincronizadas pelo implementador. As descrições históricas abaixo preservam a evidência inicial; a conferência final a seguir é a fonte do status atual.

Li os AGENTS aplicáveis, Package.swift, README.md, CONTRIBUTING.md, spec/design/tasks da V2 e a referência `tlc-spec-driven/references/validate.md`. A instrução específica da tarefa restringe escrita a este relatório e proíbe criar/modificar testes, mocks, fixtures, commits ou dados pessoais. Portanto não alterei spec/tasks, arquivos de lições ou código. O sensor depende de uma suíte base executável e permanece NOT-RUN.

## Conferência final das correções

| Achado | Estado final | Evidência atual |
| --- | --- | --- |
| F1 suspensão/ownership | CORRIGIDO por inspeção | `AppController.swift:189–194` deriva a suspensão; `329–350` recusa sobreposição e informa êxito; `366–375` adquire captura antes da sessão e encerra somente o token atual; `ContentView.swift:109–116,402–404` só apresenta prática adquirida. `RuleEditorView.swift:353` e `DescribeAutomationView.swift:34` também respeitam recusa da captura |
| F2 Hold | CORRIGIDO por inspeção | `GesturePracticeSession.swift:32–35` aceita Hold `.began` e deduplica a sessão |
| F3 relatório de cancelamento | CORRIGIDO por inspeção | `AutomationCoordinator.swift:147–156,201–204` conserva a identidade até o relatório e protege contra execuções substituídas |
| F4 diagnóstico da espera | CORRIGIDO por inspeção | `AutomationCoordinator.swift:357–367` publica reconhecimento resolvido por timeout; `AutomationExplanation.swift:26–28` agora diz “Reconhecimento parcial / Na última entrada...”, reportando o resultado histórico sem prometer que a espera continua ativa |
| F5 URL sem host | CORRIGIDO por inspeção | `AutomationDraftParser.swift:38–40` exige host não vazio e rejeita credenciais embutidas |

Build independente final: `DEVELOPER_DIR=/Library/Developer/CommandLineTools swift build --disable-sandbox --product Tico` — **PASS**, exit 0, 3,50 s. Diff check final — **PASS**. Nenhuma alteração em `Tests`.

O ajuste final do observador de ativação do painel foi conferido em `CompanionCoordinator.swift:36–46`: ele fecha somente quando o bundle atual diverge do contexto do painel. A observação do foco real do macOS continua pertencendo ao UAT nativo, não à inspeção.

**Pendente:** execução da suíte e sensor, confirmação do UAT isolado do implementador e verificações manuais indicadas abaixo. Não há recomendação de criar testes sem nova autorização.

## Histórico — primeira rodada de correções

| Achado | Estado atual | Evidência da revalidação |
| --- | --- | --- |
| F1 sobreposição Laboratório/prática | Corrigido estaticamente; resta caso de múltiplas janelas abaixo | `AppController.swift:189–194` deriva suspensão com `CombineLatest3` e OR dos três estados; `250–254,271–275,329–334` recusam sobreposição |
| F2 Hold | Corrigido estaticamente | `GesturePracticeSession.swift:28–31` aceita Hold `.began`, mantém deduplicação por sessão |
| F3 relatório cancelado | Corrigido estaticamente | `AutomationCoordinator.swift:147–156` preserva a identidade até publicar relatório; `201–204` protege contra resultado de execução substituída |
| F4 diagnóstico após timeout de prefixo completo | Corrigido parcialmente | `AutomationCoordinator.swift:357–367` publica reconhecimento antes de executar regras liberadas; falta expiração de progresso incompleto |
| F5 URL incompleta | Corrigido estaticamente | `AutomationDraftParser.swift:38–40` exige host não vazio e rejeita user/password; preserva URL original |

**F1 residual — P1, múltiplas janelas:** `TicoApp.swift:62` usa `WindowGroup` e compartilha controller/session. `AppController.beginPractice` (`362–365`) substitui a sessão antes de chamar `beginRecording`, cujo guard (`330`) retorna silenciosamente se outra gravação/prática já estiver ativa. `ContentView.practice` apresenta a sheet independentemente de êxito. Duas janelas podem mostrar prática; ao encerrar uma, `endRecording` libera a captura enquanto a outra ainda exibe a garantia de suspensão. Recusar nova prática antes de alterar a sessão e retornar êxito ao caller evita a segunda apresentação. A abertura de múltiplas janelas não foi executada neste verificador; a cadeia é diretamente derivada dos owners e callbacks.

**F4 residual — P2, sequência incompleta:** depois somente do primeiro passo de uma sequência, há `progressByRuleID`, mas nenhum `pendingMatch`. `TriggerSequenceRuntime.swift:111–114` retorna deadline somente de `pendingMatches` e `flushExpired` não remove progresso. Sem outro evento, a explicação de espera não expira. É necessário representar o prazo do progresso e publicar timeout, ou formular a explicação explicitamente como observação passada em vez de estado corrente.

**Gates da rodada 2:** `swift build` com CLT PASS (3,49 s); `git diff --check` PASS. A suíte não foi repetida porque o bloqueio de XCTest permanece e repetir a compilação não agrega evidência. Mudança do atalho da cola para ⌘⌥, do painel para ⌃⌥⌘Espaço e resolução de apps do sistema pelo Launch Services foram inspecionadas; comportamento físico/VoiceOver/foco continua NOT-RUN.

## Histórico dos achados da primeira inspeção

### F1 — P1: encerrar prática pode liberar cenas durante gravação do Laboratório

- **Local principal:** `Sources/Tico/Support/AppController.swift:338–346`, especialmente `companion.interactionIsSuspended = false`.
- **Evidência adicional:** `AppController.swift:235–239` mantém observação quando o laboratório grava; `244–268` e `320–354` iniciam atividades sem exclusão mútua; `CompanionCoordinator.swift:77–82` usa somente o booleano de suspensão para permitir execução manual; `MenuBarContentView.swift:20–24` alcança `runScene`.
- **Fluxo concreto derivado do código:** iniciar gravação no Laboratório → navegar para Explorar (a gravação permanece ativa) → Experimentar uma receita → encerrar prática → escolher uma cena no menu de status. `endRecording()` libera o booleano embora `laboratoryCoordinator.isRecording` continue verdadeiro. `canExecute` passa e a cena alcança o executor real.
- **Impacto:** viola a garantia de que prática, gravação e replay não executam automações reais. O mesmo owner compartilhado pode ser liberado por cancelamento/término de outra atividade simultânea; a assinatura de replay só escreve `false` ao terminar (`AppController.swift:165–171`).
- **Correção recomendada:** derivar a suspensão da união dos estados atuais de prática/gravação/replay ou impedir sobreposição de forma explícita; a fronteira de execução manual deve consultar a condição agregada. Encerrar uma atividade não pode liberar outra.
- **Validação necessária:** em dados isolados, manter uma atividade ativa enquanto outra começa/termina e comprovar que o comando manual continua recusado até todas terminarem. Não executar ações reais para validar.

### F2 — P2: Hold nunca incrementa a prática

- **Local:** `Sources/Tico/Support/GesturePracticeSession.swift:28–29`.
- **Evidência:** o recognizer de Hold emite `.began` (`Services/GestureRecognizers.swift:65–78`). `AdvancedGestureEngine.swift:249–257` define Hold como gesto sem fases contínuas, logo não há evento semântico `.ended` posterior de Hold. A prática descarta esse único reconhecimento antes de chamar o matcher.
- **Resultado:** praticar uma regra Hold, inclusive uma sequência que contenha Hold, permanece em 0/3 apesar de o engine reconhecer o gesto.
- **Correção recomendada:** aceitar a fase semântica de conclusão apropriada para cada família; deduplicar sessões e ignorar `.changed`/`.cancelled` sem exigir `.ended` universalmente.
- **Validação necessária:** uma regra Hold deve contar uma repetição por sessão física distinta e chegar a 3/3 sem executar seu workflow. Swipes com fases contínuas continuam contando apenas uma vez.

### F3 — P2: cancelar uma cena descarta seu relatório

- **Local principal:** `Sources/Tico/Support/AutomationCoordinator.swift:201–204`.
- **Causa:** `cancelWorkflow` cancela a task e remove sua identidade em `147–155`. Quando `WorkflowExecutor` devolve o relatório cancelado, `isCurrentWorkflow` é falso e a execução retorna antes de publicar `lastWorkflowReport`.
- **Impacto:** o spinner desaparece, mas “Última execução” continua com o resultado anterior ou não aparece. As etapas já concluídas da cena cancelada deixam de ser apresentadas, contrariando V2-04/V2-05.
- **Correção recomendada:** preservar a identidade da execução cancelada até finalizar o relatório, diferenciando cancelamento explícito de substituição por outra execução. A finalização antiga não pode sobrescrever uma execução mais recente.
- **Validação necessária:** executar uma sequência sintética com atraso, cancelar e observar relatório com `wasCancelled == true`, mantendo somente as etapas efetivamente concluídas; substituir a execução não deve publicar relatório obsoleto.

### F4 — P2: diagnóstico permanece “Aguardando” após resolução por timeout

- **Local:** `Sources/Tico/Support/AutomationCoordinator.swift:347–364` e `Services/TriggerSequenceRuntime.swift:24`.
- **Evidência:** `handle` publica a explicação “Aguardando o próximo movimento” quando há `nextDeadline`/progresso (`123–127`). O callback de deadline faz `flushExpired` e `execute(rules)` sem atualizar a explicação (`357–363`).
- **Reprodução lógica:** configurar toque simples e duplo, ou uma sequência curta que é prefixo de outra; completar a curta e aguardar. A regra curta executa por timeout, mas a explicação continua dizendo que aguarda o movimento seguinte.
- **Observação relacionada:** progresso incompleto de sequência não contribui para `nextDeadline` (`TriggerSequenceRuntime.swift:111–114`) e não é eliminado por `flushExpired`, de modo que sua explicação também não expira sozinha.
- **Correção recomendada:** publicar o resultado real ao resolver a espera e representar/expirar também o progresso de sequências incompletas. Evitar inferir “ainda aguardando” de um dicionário que contém progresso vencido.
- **Validação necessária:** conferir resolução de prefixo, desistência após timeout, incompatibilidade do movimento seguinte e atualização do diagnóstico/atalho aberto.

### F5 — P2: parser aceita links incompletos como rascunhos válidos

- **Local:** `Sources/Tico/Services/AutomationDraftParser.swift:34–40`.
- **Causa:** a verificação delegada a `RuleURLValidator.isValidWebURL` verifica somente `http`/`https` (`Support/RuleURLValidator.swift:9–11`). Foundation aceita `URL(string: "https://")` e `URL(string: "https:///pagina")`, ambos sem host.
- **Evidência executada:** comando Swift puro com Foundation produziu `accepted: true`, `scheme: https`, `host: nil` para as duas entradas. Não envolveu dados pessoais, arquivos de teste ou execução de automações.
- **Resultado:** “Quando eu fizer um toque com 3 dedos no qualquer aplicativo, abra https://” produz rascunho em vez de informar incompletude, contrariando V2-07.
- **Correção recomendada:** exigir uma URL web completa com host válido nesta fronteira e preservar os caracteres originais. Definir também como tratar pontuação da frase: hoje a normalização remove ponto final para reconhecer a frase, mas a extração da URL original mantém esse ponto no path.
- **Validação necessária:** rejeitar URL sem host, manter caixa/acentos/path/query/fragment da URL suportada e sinalizar qualquer ambiguidade de pontuação.

## Rastreabilidade dos critérios e cobertura na primeira inspeção

As sete entradas da spec agregam vários comportamentos e não definem separadamente todos os estados de erro. Nenhuma tem uma asserção automatizada completa para a V2. Evidência de implementação não é equivalente a teste aprovado.

| Critério | Resultado esperado | Evidência do código e asserção existente | Avaliação |
| --- | --- | --- | --- |
| V2-01 Painel | Próximo ao cursor, contexto atual, Escape, execução só por seleção explícita | `ContextualPanelService.swift:19–42,45–77`; `CompanionCoordinator.swift:85–138`. Não há asserção específica da V2 | PARTIAL; foco, Escape com captura parada e múltiplos monitores dependem de UAT |
| V2-02 Mapa/prática | Lista contextual e três reconhecimentos distintos, sem efeitos, restauração da captura | `GestureMapView.swift:25–49`; `GesturePracticeSession.swift:26–48`; `AppController.swift:320–359`. Sem asserção específica | FAIL: F1 e F2; deduplicação de autorepeat do teclado não comprovada |
| V2-03 Receitas | Catálogo por objetivo, ilustração, requisito de app, revisão e criação desativada | `AutomationRecipe.swift:23–28`; `ExploreView.swift:23–67`; `ContentView.swift:410–417`. Sem asserção específica | PARTIAL; inspeção mostra `isEnabled = false` em ambas as fronteiras |
| V2-04 Cenas | CRUD persistente, etapas, execução/cancelamento explícitos, reutilização de workflows | `ScenesView.swift:29–90`; `ShortcutStore.swift:306–330`. Asserção de persistência existente: `Tests/TicoTests/AutomationAndProfilesTests.swift:243` — `XCTAssertEqual(reloaded.reusableWorkflows, [workflow])` | PARTIAL; asserção é da biblioteca anterior e está BLOCKED; F1/F3 afetam execução/feedback |
| V2-05 Explicação | Causa real do resultado, contexto/inatividade/espera, relatório de etapas e abrir regra | `AutomationExplanation.swift:18–46`; `ExecutionInsightView.swift:13–30`. Teste antigo de deadline: `AdvancedPhasesTests.swift:228–234` compara `flushExpired(...).map(\.id)` a `[short.id]`; não afirma a explicação | FAIL: F3/F4; sem asserções para as novas mensagens/estado |
| V2-06 Navegação | Novos destinos destacados, antigos preservados, menu e pausa temporária | `SidebarView.swift:19–32`; `Commands.swift:28–33`; `MenuBarContentView.swift:18–35`. `MacOS26ShellBehaviorTests.swift:19–22` afirma seleção anterior e limpeza da busca, não os novos destinos | PARTIAL; pausa de 15 minutos, janela/foco e VoiceOver não executados por este verificador |
| V2-07 Texto | Gramática local restrita; erros explícitos; rascunho revisável e desativado | `AutomationDraftParser.swift:24–45,48–98`; `DescribeAutomationView.swift:43–65`. Sem asserção específica | FAIL: F5; criação desativada confirmada estaticamente |

**Cobertura automatizada completa e executada dos critérios V2: 0/7.** Isso é uma limitação explícita da autorização e do ambiente, não uma recomendação de desobedecer à proibição de novos testes. Não acrescentar testes, mocks ou fixtures sem autorização.

## Qualidade, segurança e persistência observadas

- O composition root conecta o coordinator ao `ContentView`/menu e desabilita execução manual em `isUITesting` (`TicoApp.swift:43–54`). O bloqueio de UI testing da V2 foi confirmado por inspeção, não por interação deste verificador.
- Receitas e parser criam cópias desativadas; a instalação aplica novamente `isEnabled = false`. Não há rede, execução de scripts ou modelo externo no parser.
- O painel valida novamente o aplicativo antes de executar e converte alvos relativos de janela/app em bundle ID (`CompanionCoordinator.swift:113–138`). Preservação de foco por `NSPanel.nonactivatingPanel` requer execução nativa; não foi presumida.
- A exclusão de cenas modifica apenas `reusableWorkflows` e restaura o array em erro (`ShortcutStore.swift:321–330`). O schema continua v6; biblioteca e cenas usam a mesma fonte. Nenhuma migração ou dependência foi adicionada.
- Gravação/prática retornam antes do executor automático (`AppController.swift:398–408`). A falha F1 é específica da suspensão da entrada manual quando atividades se sobrepõem.
- O desenho usa callbacks/valores na maioria das novas views e mantém AppKit fora delas. `SceneEditorView` usa rascunho local e salva explicitamente.
- Nenhum teste foi removido ou alterado. O delta de `Tests` é vazio; há 128 funções de teste no snapshot, iguais à base porque os arquivos são idênticos. Essa contagem estática não significa 128 testes executados.
- Risco a validar: pressionar e segurar um atalho de teclado gera autorepeat sem distinção em `GlobalEventTapService.normalize`; a prática filtra somente pelo intervalo de 250 ms. Não há prova de que três contagens sejam três pressões físicas.

## Gates realmente executados

| Comando | Resultado observado |
| --- | --- |
| `DEVELOPER_DIR=/Library/Developer/CommandLineTools swift build --disable-sandbox --product Tico` | PASS, exit 0, 57,62 s |
| `git diff --check` usando o Git fallback informado | PASS, exit 0, sem saída |
| `DEVELOPER_DIR=/Library/Developer/CommandLineTools swift test --disable-sandbox` | BLOCKED, exit 1 durante compilação: `no such module 'XCTest'`, zero testes executados |
| `git diff --numstat -- Tests` e contagem das funções `test` | Sem alterações nos testes; 128 definições estáticas |
| Avaliação Swift/Foundation de URLs sintéticas | PASS como investigação: confirmou URLs sem host aceitas pelo Foundation; não é uma suíte de testes |
| `TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package` | NOT-RUN neste worktree; implementador informou BLOCKED por licença do Xcode (exit 69). Não houve aceite ou contorno de licença |
| Sensor de discriminação | NOT-RUN: a suíte base não compila; mutação não poderia ser distinguida de falha do ambiente |
| UAT nativo | NOT-RUN por este verificador; em execução separada pelo implementador |
| Trackpad físico, permissões TCC, sleep/wake, vários monitores, VoiceOver, Developer ID/notarização | NOT-RUN |

## Situação das entregas e próximos passos

Todos os oito itens ainda estavam desmarcados em tasks.md no snapshot. Há implementação para as sete ideias, mas não foi correto promovê-la a verificada com base somente no build.

1. Agregar evidência do UAT isolado do implementador, preservando as distinções entre inspeção, execução observada e hardware pendente. Os cinco achados e seus resíduos foram corrigidos e reinspecionados.
2. Reexecutar a suíte/gate no ambiente com XCTest/Xcode disponível. O bloqueio da licença deve continuar explícito; sensor não pode ser declarado aprovado sem suíte base executável.
3. Validar fisicamente três sessões de Hold/swipe e teclado, retomada da captura, exclusão mútua entre janelas e Laboratório, foco do painel, cancelamento de cena e persistência após reabrir.

Paralelo com React: a suspensão atual funciona como um único booleano global escrito por componentes diferentes; o estado necessário é derivado de todos os owners ativos, para um cleanup local não reabilitar efeitos globais de outra interação. O equivalente pedagógico é calcular `recording || replaying || practicing` a partir das fontes de verdade, sem copiar e desfazer um estado compartilhado independentemente.

Não registrei lições em outros arquivos porque a delegação autorizou escrita somente neste relatório. Não modifiquei código real, testes, fixtures, dados privados ou memória.
