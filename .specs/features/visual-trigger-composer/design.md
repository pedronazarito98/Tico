# Criador visual de acionamentos

## Direção aprovada

Implementar no Tico nativo a opção visual 1 e os 12 estados complementares aprovados em 29/09/2026. Manter SwiftUI, SwiftPM, macOS 26+, tokens, identidade, formato persistido e motor de execução existentes.

O fluxo é Ação → Como ativar → Experimentar. O candidato de captura é temporário; confirmar transfere o valor à sessão de edição. Somente Salvar persiste. A prática usa o matcher e demonstra o resultado sem executar workflows.

## Interações

- Teclado: nomes do layout ativo, seleção visual, modificadores, captura local de keyDown/keyUp/flagsChanged. Soltar modificadores não troca a combinação confirmável. Esc encerra a captura; sair do app também remove o monitor.
- Trackpad: contatos e trajetória observados, seleção de movimento/dedos, demonstração identificada e respeitando Reduzir Movimento. A conversão para gatilho preserva modificadores.
- Mouse: botão do meio e botões extras, com modificadores; cliques primários e rolagem continuam fora do contrato do monitor global.
- Personalizado: três amostras válidas, repetição individual e preservação das demais; nome e diagnóstico de trajetória/dedos.
- Sequência: duas a cinco entradas, editar, ordenar, remover, intervalo e política de prefixo existentes.
- Revisão: gatilho → ação, nome, escopo por checkboxes, ativação, acesso aos ajustes e workflows completos.
- Conflitos: usar o analisador existente. Contextos mais específicos continuam com prioridade. Substituição é explícita.
- Biblioteca: switches, menu de ações e duplicação em rascunho pausado.

## Fronteiras

AppController mantém a exclusão entre captura, prática, laboratório e replay. LocalInputCaptureService é a ponte AppKit de uma janela. Views recebem valores, sessões estreitas e callbacks. RuleEditingSession permanece a fonte do rascunho persistível.

Paralelo com React: @StateObject possui a sessão local; @ObservedObject observa essa mesma instância nos filhos; Binding representa um campo controlado. O monitor AppKit é um efeito com início e limpeza explícitos, separado da árvore visual.

Não há migração de schema: uma combinação de teclado contém uma tecla não modificadora e um conjunto de modificadores. Acordes arbitrários de letras simultâneas e letra mantida + trackpad não cabem nesse contrato. O gravador precisa explicitar isso. Sequência representa entradas em ordem, sem fingir simultaneidade.

## Verificação

Executar os gates canônicos, o fluxo UI existente e inspeção nativa isolada. Hardware físico, TCC real, VoiceOver e notarização precisam de evidência própria; build ou replay não os substituem. Resultados observados ficam em validation.md e design-qa.md.
