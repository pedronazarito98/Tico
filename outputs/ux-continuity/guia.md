# Tico — experiência revisada

A revisão mantém ações, sequências, condições, perfis, gestos personalizados e opções de precisão. O caminho principal apresenta o resultado primeiro; detalhes aparecem quando fazem diferença.

## Criar e editar um atalho

1. Em **Meus atalhos**, escolha **Novo atalho**.
2. Escolha o resultado. Os parâmetros aparecem no mesmo passo: por exemplo, abrir um site pede o endereço; abrir um app já mostra o app escolhido.
3. **Mais ações e opções** revela a sequência completa. Todas as ações continuam na busca e em **Todas as ações**.
4. Em **Como ativar**, escolha **Gravar** ou **Escolher**. Valores ilustrativos iniciais não contam como escolha. Sequências, desenho e ajustes avançados permanecem disponíveis.
5. Confira destino, acionamento e escopo. **Testar acionamento** ensaia o reconhecimento, sem executar efeitos reais. **Ativar ao salvar** é uma decisão separada.
6. Salve. Cancelar antes disso não cria uma regra. Editar e personalizar modelos usam esse mesmo criador.

No detalhe do atalho, **Ativado** significa que a regra está habilitada. Se a captura global estiver pausada, a mensagem explica que ainda é necessário retomá-la. O menu no rodapé da barra lateral controla essa captura.

## Fazer com conteúdo

Abra **Atalhos → Fazer com conteúdo…**. Google e documentação Apple aparecem mesmo sem regras configuradas.

- Digite uma entrada demonstrativa, por exemplo `documentação SwiftUI`.
- Abra **Nova receita**, escolha o destino e volte. A entrada deve continuar no painel.
- Salvar uma receita guarda apenas sua configuração; a ação ainda depende de um clique explícito na lista.
- “Enviar para um Atalho do macOS…” permite procurar ou escrever o nome do Atalho receptor. “Outro site” expõe endereço e parâmetro da pesquisa.
- Texto/link e arquivos permanecem apenas na sessão. Fechar, limpar, cancelar a execução ou concluir com sucesso removem a entrada. A inatividade de cinco minutos também a remove. Navegar pelo editor de receita não renova o prazo.

As receitas manuais não precisam de um gatilho. Regras com sequências continuam usando o executor existente. O novo arquivo `content-recipes.json` guarda somente ID, nome e configuração; ele ainda não participa do import/export das regras.

## Cenas na própria tela do Mac

Em **Cenas → Nova cena**, escolha **Guardar disposição atual** ou **Montar uma cena**. Ao montar, adicione aplicativos/ações e use **Organizar estes aplicativos** para planejar posições sem consultar janelas.

Selecione uma janela no desenho ou nos botões abaixo dele. Escolha esquerda, tela inteira, direita ou outra posição. Tela de destino, escolha de janela e precisão continuam nos detalhes. O nome pode ser sugerido pelos apps.

Ao preparar uma cena, as ações executam primeiro; a revisão mostra a disposição atual e planejada. Só as janelas ambíguas pedem uma escolha. **Aplicar disposição** confirma a movimentação. Após isso, escolha **Voltar à disposição anterior** ou **Manter esta disposição** antes de aplicar outro layout.

A revisão possui até cinco minutos, separados do orçamento de execução. Ao expirar, **Retomar revisão** consulta novas janelas e executa somente o layout. Não repete aplicativos, links nem scripts anteriores. Alterar/excluir a origem invalida essa pendência. Pausar captura e cancelar a cena também alcançam a retomada.

## Rotinas de telas

No menu de uma cena, use **Usar quando…**. A cena já vem escolhida. Na criação genérica, a escolha é explícita.

Escolha a mudança e o comportamento. **Salvar pausada** conserva a configuração sem ativá-la. **Ativar sugestão** ou **Ativar execução** explicam também quando vão retomar o monitoramento global. O modo automático só fica disponível quando a cena é elegível; se a configuração passar a exigir confirmação, a interface apresenta o modo efetivo de sugestão.

É possível configurar usando somente a tela do Mac. Disparos de conexão/desconexão ainda precisam de um monitor externo para serem exercitados fisicamente.

## Aprendizado, ideias e modelos

O **Mapa de gestos** usa lista compacta e detalhe permanente. Escolha um atalho para praticar ou acompanhar seu uso real. Silenciar dicas não pausa o progresso. Reiniciar um atalho não apaga conclusões de outros; reinício global fica separado e pede confirmação.

**Explorar** oferece cartões estáticos, filtros por objetivo e busca na própria seção. **Personalizar** abre o criador. **Modelos e gestos** começa pelos modelos salvos e conserva a consulta dos gestos ensinados.

**Descrever automação** oferece uma frase montada por escolhas e texto livre com exemplos de gramática. O processamento é local e restrito às estruturas mostradas. A proposta abre o criador antes de qualquer persistência.

## Paralelo com React

`RuleEditingSession` é o estado elevado do formulário: etapas recebem `Binding` e callbacks, como componentes controlados. Não há um formulário independente por sheet. `@State` mantém seleção, expansão e rascunhos locais; stores continuam responsáveis pela configuração persistida.

`@ObservedObject` assina os owners usados por cada tela. Objetos observáveis aninhados precisam de assinatura explícita: observar o coordenador externo não propaga automaticamente as alterações dos stores internos.

O cancelamento de captura usa um token da instância do editor, comparável a encerrar apenas a requisição iniciada por aquele componente. A reserva da cena e os handles de janelas pertencem à sessão/serviço, fora da view.

## Conferência visual

Capturas da interface real, usando rascunhos e entrada demonstrativa:

- [Resultado no criador](screens/criador-resultado.jpg)
- [Escolha visual do acionamento](screens/criador-acionamento.jpg)
- [Conferência do atalho](screens/criador-conferir.jpg)
- [Painel de conteúdo](screens/conteudo.jpg)
- [Descrição guiada](screens/descrever.jpg)
- [Planejamento de posições](screens/cena-posicoes.jpg) — capturada antes do ajuste de rótulo de “Capturar novamente” para “Usar janelas abertas”.

O [registro de validação](../../.specs/features/ux-continuity/validation.md) separa os gates executados dos percursos que ainda precisam de hardware, permissões ou efeitos reais.
