# Experiências contextuais do Tico

Autorização: em 19/10/2026, o usuário pediu implementar integralmente as ideias
2, 3, 5 e 6: conteúdo contextual, aprendizado durante o uso, cenas reversíveis
e rotinas de monitor, com comportamento robusto e interface minimalista.

## Contratos de produto

- **CTX-01 Conteúdo:** texto, URLs e arquivos fornecidos explicitamente; seleção
  de texto consultada por Acessibilidade somente quando uma ação configurada a
  solicita. Conteúdo é efêmero, limitado e tipado; não entra em documentos,
  histórico, métricas, logs nem mensagens de processos. Nunca ler clipboard,
  simular copiar, consultar campos seguros ou executar conteúdo como código.
- **CTX-02 Execução:** todas as entradas passam pelo executor central. Uma
  seleção no início do workflow é fixada antes de qualquer etapa. Erros de
  seleção são explícitos, sem recorrer a outro aplicativo ou conteúdo antigo.
  Cancelamento, timeout, limpeza de arquivos temporários e resultados sanitizados
  fazem parte do fluxo. Pesquisa deve codificar a entrada como dado de URL.
- **LRN-01 Aprendizado:** adesão explícita, um objetivo ativo, dicas somente
  após sucesso pelo painel, progresso somente por execução real do atalho.
  Adiar, dispensar, concluir e reiniciar são ações visíveis. Prática e replay
  não contam como uso real. Persistir apenas configuração e progresso agregado.
- **SCN-01 Cenas:** manter ActionWorkflow como fonte de verdade. Acrescentar
  layout opcional, captura explícita, prévia antes/depois, edição, execução e
  relatório por janela. Não capturar títulos, conteúdo ou imagens das janelas.
- **SCN-02 Recuperação:** restaurar somente as janelas exatas modificadas pelo
  Tico, com identidade transitória, verificação de drift e leitura de retorno.
  Falha/cancelamento parcial preserva recuperação. Mudança de app, janela ou
  monitor deve produzir resultado explícito; não prometer restaurar documentos,
  abas, Spaces ou aplicativos fechados.
- **DSP-01 Rotinas:** conexão/desconexão de telas usa topologia e papéis, sem
  persistir identificadores físicos. Inicialização, wake e retomada estabelecem
  baseline; eventos repetidos são coalescidos. Sugestão é o padrão; automático
  exige escolha explícita e só aceita ações elegíveis. Revalidar intenção,
  workflow e topologia antes de executar; interromper durante suspensão.
- **UX-01 Interface:** integrar conteúdo ao painel, aprendizado ao Mapa e
  rotinas às Cenas. Sem dependências, novos frameworks ou nova navegação principal.
  Estados vazios, falhas, progresso, cancelamento, acessibilidade, teclado,
  light/dark e Reduzir Movimento devem permanecer coerentes.
- **VAL-01 Isolamento:** UI testing, replay, laboratório e gravação nunca
  executam automações reais. Dados de desenvolvimento são isolados dos dados
  pessoais. Nenhum novo teste, mock ou fixture sem pedido explícito.

## Persistência e compatibilidade

O documento de atalhos passa à versão 7, com configurações opcionais de conteúdo
e layout. A migração aceita documentos anteriores e usa o backup versionado
existente. Aprendizado e rotinas têm arquivos próprios no mesmo diretório Tico,
com URL injetada, limites de leitura, validação e escrita atômica antes de publicar
estado. A revisão salva de cada atalho invalida aprendizado desatualizado.
Nenhum dado real foi migrado nesta tarefa.

## Investigação e ownership

A skill reverse-engineer-anything orientou a investigação do código-fonte completo
e a observação de uma execução isolada pelo REA. O primeiro binário SwiftPM direto
não ofereceu identidade de processo suficiente para a observação; um bundle local
ad hoc iniciado com `--ui-testing` permitiu inspecionar a interface e os estados de
edição sem automações reais. A evidência e seus limites estão em `validation.md`.
Três worktrees isolados dividiram conteúdo, cenas e aprendizado/rotinas; a integração
serial no composition root preservou mudanças locais anteriores do criador visual.

## Paralelo com React

Stores e sessões observáveis são owners de estado; views recebem projeções e
ações. Serviços isolam efeitos de plataforma, como um adaptador usado por um
hook, mas AppKit, Acessibilidade e ciclo de vida global não pertencem à árvore
SwiftUI nem equivalem a efeitos de montagem de um componente.

## Gates

Build SwiftPM e suíte existente; revisão dos fluxos de erro e segurança; gate
canônico completo; UAT isolado de edição/navegação. Hardware, TCC real, operações
em aplicativos de terceiros, VoiceOver, sleep/wake e monitores físicos requerem
evidência própria e não serão inferidos de build ou replay.
