# UX contínua — evidência de implementação

20 de outubro de 2026. Implementação local da revisão aprovada em `outputs/ux-audit-2026-10-20/relatorio.md`.

## Escopo e preservação

Três agentes trabalharam em worktrees isolados; a integração e a inspeção da interface foram feitas na raiz. O inventário em `files.md` compara os fontes com o snapshot anterior a esta fase, preservando as mudanças que já existiam no checkout: **74 arquivos Swift alterados nesta fase, sendo 20 novos**.

Não foram criados testes, mocks ou fixtures. Os testes de interface e scripts já modificados no checkout antes desta fase foram preservados. Sem dependências adicionais, commit, push, PR ou publicação.

## Verificações automatizadas

| Verificação | Resultado |
|---|---|
| `git diff --check` | PASS |
| `swift build --disable-sandbox --product Tico` | PASS, incluindo a integração e as correções finais de interação |
| `swift test --disable-sandbox -q` | PASS: 128 testes existentes, zero falhas |
| `TICO_UI_TEST_DERIVED_DATA_PATH=/private/tmp/TicoUXValidation-20261020 ./script/run_ui_tests.sh` | PASS: um fluxo existente de criação, persistência e reabertura, com dados isolados |
| `TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/build_and_run.sh --package` | PASS: pacote local ad hoc, ZIP e DMG |
| `TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package` sobre a revisão final | PASS, saída 0: build SwiftPM, app Xcode, arquivo Release arm64 + x86_64, XCUITest isolado, 128 testes, reexecução dos 8 testes de segurança, ZIP/DMG e preflight |

O gate final usou `TICO_UI_TEST_DERIVED_DATA_PATH=/private/tmp/TicoUXValidation-20261020` para reutilizar os artefatos de compilação do runner; os dados do aplicativo continuaram isolados pelo próprio teste. Os 8 testes de segurança já fazem parte dos 128 e foram executados novamente pelo gate.

Os avisos de depreciação de `hdiutil attach/detach` não impediram a criação, montagem somente leitura, verificação de checksum e preflight dos pacotes.

O primeiro gate integrado encontrou uma regressão de acessibilidade no indicador da barra lateral: colocar o indicador inteiro dentro de um `Menu` fazia o teste receber um rótulo vazio. O texto de estado voltou a ser um elemento separado, com identificador estável, e o menu de controle ficou ao lado. O mesmo teste passou depois da correção; nenhuma assertion foi removida ou enfraquecida.

A suíte existente fornece evidência de regressão do produto. Ela não cobre automaticamente todos os estados novos de receitas, revisão de cenas, aprendizado e rotinas.

## Inspeção interativa realizada

As conferências abaixo usaram rascunhos descartáveis e texto demonstrativo no aplicativo local. Não salvaram novos atalhos, cenas ou receitas; não executaram ações nem movimentaram janelas. A captura global permaneceu pausada.

| Percurso | Resultado observado |
|---|---|
| Criar ação para abrir site | Endereço começa vazio, configuração aparece na própria etapa e impede avanço enquanto incompleta |
| Escolher acionamento | Galeria de trackpad exige escolha explícita; o resumo mostra acionamento e destino concretos |
| Trocar dispositivo no build final | Depois de selecionar “Escolher” no teclado, trocar para Trackpad manteve “Escolher” e mostrou a galeria, sem iniciar gravação |
| Descartar atalho | Confirmação de descarte quando há alterações; coleção existente preservada |
| Painel de conteúdo | Google e documentação Apple disponíveis; nenhuma seleção pessoal lida ao abrir o painel genérico |
| Nova receita e retorno | Entrada demonstrativa permaneceu intacta ao abrir destino personalizado e voltar sem salvar; destino incompleto desabilitou salvar |
| Descrição guiada | Escolhas geraram proposta; “Personalizar no editor” abriu o criador com resultado e acionamento preenchidos, antes de persistir |
| Montar cena | Aplicativo adicionado somente ao rascunho; “Organizar estes aplicativos” criou plano sem consultar janelas |
| Posição da cena | Escolher metade esquerda atualizou a representação visual; controles de tela e precisão ficaram recolhidos |
| Descartar cena | Confirmação explícita; lista continuou sem a cena demonstrativa |
| Busca em Explorar | Filtrou a ideia de Terminal sem mudar para Meus atalhos |

A inspeção encontrou um retorno indevido de “Escolher” para “Gravar” ao trocar o dispositivo. O setter de dispositivo foi corrigido para preservar o método escolhido; a correção foi conferida na interface após o gate final. Também foi ajustado o rótulo para substituir um plano com as janelas abertas, sem presumir que o plano tenha sido capturado antes.

As capturas de interface estão em `outputs/ux-continuity/screens/`. Elas mostram os estados inspecionados; a captura da cena foi feita antes desse último ajuste de rótulo.

Ao finalizar, `dist/Tico.app` foi aberto novamente em **Meus atalhos**, com os rascunhos de inspeção descartados e a captura global ainda pausada.

## Revisão estática adicional

Os agentes revisaram os contratos de rascunho, persistência e cancelamento após a integração. A revisão identificou e a raiz corrigiu:

- Instalar uma cena apenas com layout não deve materializar uma ação de fallback ao atravessar o criador.
- A expiração e retomada da revisão precisam conservar a origem completa, revalidá-la e impedir repetição das ações anteriores.
- Editar ou excluir a origem precisa invalidar uma revisão pendente.
- Fechar um editor deve cancelar somente a captura iniciada por aquela instância.
- Adicionar arquivos na sessão de conteúdo não deve apagar o texto já digitado.
- O catálogo de Atalhos do macOS precisa propagar atualizações ao painel de conteúdo.

Esses itens têm evidência de fonte, compilação e revisão. Os efeitos reais de acessibilidade e o ciclo completo de expiração/retomada não foram exercitados manualmente nesta rodada.

## Limites da validação

- **BLOCKED na inspeção extra:** as tentativas de iniciar manualmente uma cópia isolada não produziram uma sessão confiável de inspeção; houve falhas de lançamento com SIGTRAP. Os caminhos e as variáveis exigidos pelo modo de teste foram conferidos, e um probe somente Foundation passou. A causa de inicialização AppKit não foi determinada. Não foram lidos logs pessoais, crashlogs, TCC ou bancos de autenticação. Isso é separado do XCUITest isolado, que passou.
- **NOT-RUN:** trackpad físico, nova concessão de TCC, VoiceOver, navegação integral por teclado, Reduce Motion, contraste medido, dark mode, sleep/wake e execução real com aplicativos externos.
- **NOT-RUN:** conexão/desconexão de monitor externo; o cenário disponível continua sendo a tela do Mac.
- **NOT-RUN:** efeitos reais de receitas, progresso por uso físico, reset de aprendizado e persistência de novas rotinas pelo percurso manual.
- **NOT-RUN:** assinatura Developer ID, notarização, instalação em máquina limpa e validação com participantes. O pacote gerado é local e ad hoc.

## Persistência e compatibilidade

Regras, gestos, sequências, condições e perfis conservam o modelo existente. A configuração das receitas manuais fica em `content-recipes.json`, ao lado do arquivo de regras, sem guardar entrada de texto, seleção ou arquivos enviados. O repositório usa validação de versão/limites/identidade e gravação atômica; corrupção bloqueia sobrescrita.

O import/export de regras existente **ainda não inclui as receitas manuais**. Essa limitação também está no README e no guia de uso; não considerar exportar regras como backup dessas receitas.

## Próxima validação manual

Usar `outputs/ux-continuity/guia.md` para criar um atalho real, ensaiar seu acionamento e decidir explicitamente quando ativá-lo. Depois validar uma receita com conteúdo não sensível, aprendizado com dicas silenciadas, uma cena com duas janelas e sua recuperação. Rotinas de conexão precisam de uma sessão posterior com monitor externo.
