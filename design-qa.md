# QA visual — criador de atalhos do Tico

Data: 29/09/2026.

**final result: passed**

Resultado limitado à comparação visual e aos estados nativos observados nesta revisão. Validação física, TCC e acessibilidade assistiva têm status próprio em [.specs/features/visual-trigger-composer/validation.md](.specs/features/visual-trigger-composer/validation.md).

## Referência e implementação

- Verdade visual: `$CODEX_HOME/visualizations/2026/09/29/01a0ed93-32e0-7510-94f7-65568c2480aa/tico-fluxo-aprovado/02-teclado-aprovado.png` e os estados complementares da mesma pasta.
- Captura final: `$CODEX_HOME/visualizations/2026/09/29/01a0ed93-32e0-7510-94f7-65568c2480aa/tico-implementacao/02-teclado-final.png`.
- Estado comparado: novo atalho, Centralizar janela, etapa Como ativar, teclado, Command + Option + S selecionado, tema claro, gravação encerrada.
- Viewport nativo: sheet de 1040 × 760 pontos, captura de 2080 × 1520 pixels, densidade 2×. CSS não se aplica ao aplicativo SwiftUI.
- Fonte: 1487 × 1058 pixels, sem viewport lógico declarado. Normalizada proporcionalmente para 1040 × 740; implementação para 1040 × 760. A diferença de proporção permanece explícita; nenhuma conclusão de igualdade pixel a pixel foi usada.
- Comparação de vista completa: `tico-implementacao/comparacao-teclado.png`, ambas as imagens no mesmo arquivo/input de revisão.
- Comparação de região: `tico-implementacao/comparacao-teclado-detalhe.png`, teclado e modificadores recortados de cada imagem e normalizados à mesma largura. Conferidos letras, setas empilhadas, seleção, espaçamento e rótulos.

Uma captura intermediária incluiu a janela da biblioteca por trás do sheet. Ela foi substituída pela captura do compositor isolado antes da comparação final.

## Achados e decisões

Não restaram achados visuais P0/P1/P2 na superfície comparada após os ajustes. As diferenças abaixo são adaptações intencionais à implementação nativa:

- A gravação começa por uma ação explícita. O título e a instrução indicam Gravar; as teclas selecionadas permanecem visíveis ao encerrar.
- Picker segmentado, menus, popovers, switches e alertas usam controles do macOS e os tokens existentes do Tico. O alerta de conflito mantém a aparência do sistema.
- O teclado é um conjunto de controles SwiftUI acessíveis. Letras usam o layout ativo; teclas especiais usam símbolos reconhecíveis e nomes de acessibilidade. Não é uma imagem estática.
- Fora da gravação, os dois lados de Command/Option representam o mesmo modificador lógico. Durante a gravação, o destaque acompanha as teclas físicas observadas.
- O menu Combinar ou criar uma sequência reúne opções adicionais. O gesto combinado usa modificadores compatíveis com o contrato existente.
- O teclado ocupa uma largura menor proporcionalmente que a referência, preservando a leitura e espaço para Gravar, a instrução e os ajustes. Rodapé e CTA permanecem visíveis.

## Superfícies obrigatórias

| Superfície | Avaliação |
| --- | --- |
| Fontes e tipografia | Fonte de sistema do macOS, título semibold de 27 pt, cabeçalhos e texto auxiliar com hierarquia distinta. Família visual coerente com a referência. Rótulos e instruções sem truncamento na captura final. Não se afirma equivalência exata com uma fonte embutida na imagem gerada. |
| Espaçamento e ritmo | Ordem cabeçalho → etapas → ação → instrução → entrada → teclado → opções → rodapé preservada. Ajustados espaçamentos para manter os controles principais no sheet de 1040 × 760. Conteúdo longo possui rolagem; rodapé fixo. Voltar ao topo ao mudar etapa/dispositivo/modo foi implementado. |
| Cores e tokens | Superfície clara levemente violeta, seleção roxa e estados semânticos preservados por `TicoBrand`. Tema escuro observado separadamente no teclado e mouse. Auditoria quantitativa de contraste de todos os tokens não foi executada. |
| Imagem e ícones | Marca Tico e preview de janela existentes preservados. SF Symbols nos controles. Teclado, trackpad e mouse são representações interativas nativas, necessárias para seleção, contatos e trajetória; não são arte decorativa nova. Sem imagens esticadas ou rasterizadas nos controles. |
| Texto e conteúdo | Instruções em pt-BR e exemplos concretos. Números de keycode substituídos por nomes de teclas. Limites de combinações e botões são explicados no contexto. Permissões aparecem quando necessárias. |

## Histórico da revisão

| Achado anterior | Ajuste | Evidência posterior |
| --- | --- | --- |
| P2: excesso de controles e espaço vertical na etapa de teclado | Menu único de modos, redução de padding e separação entre conteúdo rolável e rodapé | `02-teclado-final.png`, comparação completa |
| P2: geometria de setas e seleção ao soltar modificadores pouco claras | Setas superior/inferior empilhadas, candidato separado de estado de teclas pressionadas | `comparacao-teclado-detalhe.png` e captura/regravação observadas |
| P2: representação de mouse pouco útil para seleção | Roda e botões laterais clicáveis, com seleção e nomes acessíveis | `04-mouse-dark.png` e AX com Clique do meio selecionado |
| P2: alterações descartadas poderiam reaparecer ao reabrir o editor | Reverter a sessão ao confirmar descarte; comparar candidato antes de perguntar | Nome original confirmado ao reabrir o pacote final; fechamento sem alterações observado |

Os ajustes de geometria, espaçamento e mouse foram capturados novamente. A comparação normalizada final foi feita após esses ajustes e não gerou outra mudança visual necessária.

## Interações e estados observados

- Seleção de ação, captura de teclado, seleção manual, confirmação e revisão.
- Estado gravando, controles desabilitados e encerramento com Escape.
- Prévia de prática com sucesso e entrada divergente.
- Sequência: adicionar, editar, confirmar alteração, ordenar e praticar.
- Popover de aplicativos com checkbox, fechamento e preservação da seleção.
- Switch de ativação, salvar pausado e reabrir dados persistidos.
- Conflito exato e retorno a Alterar acionamento.
- Configuração de trackpad e combinação, demonstração animada e aviso de permissão.
- Tela vazia de três amostras personalizadas com confirmação indisponível.
- Mouse clicável e captura do botão do meio.
- Biblioteca e duplicação como rascunho pausado.
- Teclado e mouse em tema escuro. A aparência do sistema do usuário não foi alterada.

## Evidências complementares

Todas na pasta absoluta `tico-implementacao` indicada acima:

- `02-teclado-dark.png`: tema escuro.
- `04-mouse-dark.png`: roda/botões clicáveis e seleção.
- `06-trackpad-combinado.png`: modificadores, gesto e permissão.
- `08-conflito.png`: decisão antes de substituir.
- `09-revisao.png`: sequência com escopo Safari e ativação desligada.
- `10-pratica-sucesso.png`: sequência reconhecida na prática segura.
- `13-biblioteca.png`: atalho persistido na biblioteca.

## Checklist de implementação

- [x] Direção aprovada aplicada ao aplicativo nativo.
- [x] Vista completa e região do teclado comparadas no mesmo input visual.
- [x] Fontes, espaçamento, cores, imagens/ícones e conteúdo revisados.
- [x] Controles centrais funcionais e estados observados documentados.
- [x] Gate automatizado completo executado com sucesso.
- [x] Limites e verificações pendentes registrados sem inferir aprovação.

## Refinamentos P3 e cobertura restante

- A profundidade/sombra das keycaps é mais discreta que na referência gerada; pode ser refinada após uso real.
- Pode-se ampliar os nomes visíveis dos modificadores além dos símbolos. Os nomes já existem em ajuda e acessibilidade.
- VoiceOver, Reduzir Movimento no sistema, texto ampliado, todas as resoluções de tela, contraste quantitativo e hardware físico permanecem fora da cobertura observada. O resultado visual acima não certifica esses cenários.
