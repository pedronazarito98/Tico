# Foundation Models local no Tico

## Escopo

Dois recursos opcionais usam exclusivamente `SystemLanguageModel.default`:

- Atalhos → Descrever automação → Linguagem natural: transforma uma descrição
  em um rascunho revisável no editor existente, inicialmente desativado.
- Atalhos → Fazer com conteúdo (ou Usar texto selecionado): oferece Resumir,
  Revisar escrita, Deixar mais direto e Extrair tarefas para entradas de texto.

Não há serviços remotos, downloads próprios de pesos, credenciais, novos packages,
tool calling nem mudança no schema de regras. Tradução, voz e geração de scripts
não fazem parte deste escopo.

## Revisão e limites

A automação aceita uma ação do conjunto já suportado pelo parser: posicionar
janela à esquerda/direita, maximizar, centralizar, reabrir última aba, abrir app
ou link HTTP(S). O gatilho é um toque/swipe com 2–5 dedos ou um gesto gravado
referenciado explicitamente. Aplicativos são resolvidos pelo catálogo local e
links precisam corresponder integralmente a um endereço presente na frase.
Condições adicionais e sequências devem ser configuradas no editor.

Geração guiada restringe o formato, não comprova a interpretação. A pessoa deve
conferir gatilho, escopo e ação antes de continuar. Campos ausentes, aplicativos
ambíguos e propostas inválidas impedem a criação. Nenhuma proposta é salva ou
executada automaticamente; prompts da IA não são copiados para as notas.

A transformação mantém o original na entrada e uma proposta editável separada.
Usar no painel promove a revisão à entrada, sem executar ações. Copiar atualiza
somente o clipboard após o clique; não envia teclas nem substitui texto em outro
app. Descartar conserva o original. Escolher outra entrada ou ação descarta a
revisão anterior. Nada desse conteúdo integra regras, histórico ou relatórios.

- Descrição: até 1.000 caracteres e 4.000 bytes UTF-8.
- Transformação: até 2.000 bytes UTF-8, com saída limitada pelo runtime.
- Revisão editada: respeita o limite existente de 64 KB da entrada de texto.
- Geração: cancelável, com prazo de 60 segundos.
- Conteúdo do painel: expira após cinco minutos sem uso; fechar, limpar ou
  cancelar uma geração apaga original e revisão. Copiar deixa a cópia escolhida
  no clipboard, que passa a ser controlado pelo sistema e pelo usuário.

## Ownership e concorrência

O `AppController` constrói um serviço injetado nos dois fluxos. O actor serializa
as solicitações e mantém uma flag durante as suspensões para impedir gerações
simultâneas. Cada chamada cria sua própria `LanguageModelSession`, descartável e
sem transcript compartilhado. A resposta nunca recebe um executor de ações.

`AutomationIntelligenceSession` pertence ao modo de linguagem natural da sheet.
`ContentPanelSession` continua como única fonte de verdade da entrada e da revisão
do painel. Ambas invalidam respostas tardias por tokens de geração, além do
cancelamento cooperativo. Os erros publicados são mensagens fixas sanitizadas.

Paralelo com React: o serviço equivale à fronteira assíncrona fora do componente;
as sessões observáveis cuidam de loading, resultado e cleanup. `@Generable` orienta
a produção do DTO, mas a validação de domínio continua separada.

## Disponibilidade

O app consulta a disponibilidade do modelo e o suporte a `pt_BR` ao abrir a UI,
ao voltar ao estado ativo e pelo botão Verificar novamente. O serviço revalida
antes de cada inferência. As opções manuais permanecem disponíveis quando o Mac
não é elegível, Apple Intelligence está desativado ou o modelo não está pronto.

Os limites de entrada são conservadores; o contexto ainda depende da tokenização
e da versão do modelo. Erros do SDK não refletem o prompt na interface. Mudanças
do modelo distribuídas pela Apple exigem repetir a avaliação com frases reais.

## Validação

Registro da implementação em 26/10/2026. Não foram criados testes, mocks ou fixtures.
Evidência interativa em uma cópia temporária com bundle identifier próprio,
dados/preferências isolados e execução real de automações bloqueada:

- Modelo disponível e suporte a `pt_BR` confirmados neste Mac.
- Uma frase com ordem livre gerou swipe à direita, três dedos e escopo Safari.
- Personalizar abriu o composer existente; Ativar ao salvar permaneceu desligado.
- Cancelar o composer preservou as duas regras iniciais da instância isolada.
- As quatro transformações produziram respostas reais do modelo local.
- Editar a proposta e Usar no painel aplicou somente o texto revisado à entrada.
- Descartar manteve a entrada original; mudar a entrada removeu a revisão anterior.
- Fechar e reabrir o painel mostrou entrada vazia e nenhuma revisão antiga.
- Inspeção visual em modo claro confirmou original, revisão editável e controles.
- Diagnóstico sintético adicional confirmou extração de toque/maximizar e
  swipe/direita, além da rejeição de uma condição de horário não suportada.

A primeira avaliação expôs uma classificação incorreta de frases válidas. O DTO
passou a orientar explicitamente os campos e classificar o suporte por último,
com exemplos no contexto de instruções. Os cenários acima foram repetidos com
esse ajuste. Isso não substitui uma avaliação ampla da qualidade do modelo.

NOT-RUN: captura real de seleção em app externo/TCC, copiar para o clipboard
real, cancelamento durante inferência e timeout de 60 segundos, espera integral
pela expiração de cinco minutos, modelo indisponível em hardware real, VoiceOver,
modo escuro, desempenho com captura ativa e notarização. Os caminhos de
cancelamento/expiração e invalidação foram revisados no código.

Gates executados no código final:

| Verificação | Resultado |
| --- | --- |
| `git diff --check` | PASS |
| `swift build --disable-sandbox --product Tico` | PASS |
| `swift test --disable-sandbox` | PASS — 128 testes existentes |
| `swift test --disable-sandbox --filter SecurityRegressionTests` | PASS — 8 testes existentes, já incluídos na suíte completa |
| Host Xcode Debug e archive Release universal | PASS — arm64 + x86_64, target macOS 26 preservado |
| `TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/build_and_run.sh --package` | PASS — app, ZIP e DMG locais ad hoc |
| `./script/release_preflight.sh dist/Tico.zip` e `dist/Tico.dmg` | PASS para desenvolvimento local; não notarizados |
| `TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package` | BLOCKED na inicialização do runner XCUITest |

O gate completo interrompeu antes dos cenários de UI: o runner expirou ao ativar
o modo de automação do macOS (`Timed out while enabling automation mode`).
Nenhuma assertion foi alterada ou pulada. A suíte Swift, a regressão de segurança
e os preflights foram executados separadamente após a interrupção. A repetição
isolada de `./script/run_ui_tests.sh` também terminou com o mesmo erro de
inicialização (exit 65). XCUITest permanece BLOCKED; a validação interativa acima
foi feita pela interface nativa, sem o runner XCTest.

Validação manual adicional recomendada:

1. Descrever gestos e ações com variações de português; conferir a interpretação.
2. Tentar campos ausentes, apps ambíguos, condições extras e URLs diferentes.
3. Editar ou cancelar durante uma geração; fechar e reabrir sem resposta antiga.
4. Transformar texto explicitamente selecionado em outro app e revisar o resultado.
5. Editar, descartar, copiar e usar no painel; conferir que não há execução implícita.
6. Verificar os estados de modelo indisponível e texto longo, além de VoiceOver,
   light/dark mode e impacto no uso do trackpad com captura ativa.

## Arquivos da implementação

- Modificado: `README.md`
- Modificado: `Sources/Tico/Support/AppController.swift`
- Modificado: `Sources/Tico/Support/ContentInteractionCoordinator.swift`
- Modificado: `Sources/Tico/Views/Components/Content/ContentActionPanelView.swift`
- Modificado: `Sources/Tico/Views/Components/Content/ContentPanelFooterView.swift`
- Modificado: `Sources/Tico/Views/Components/Content/ContentPanelSession.swift`
- Modificado: `Sources/Tico/Views/ContentView.swift`
- Modificado: `Sources/Tico/Views/DescribeAutomationView.swift`
- Criado: `Sources/Tico/Models/ContentTransformation.swift`
- Criado: `Sources/Tico/Models/LocalIntelligenceState.swift`
- Criado: `Sources/Tico/Services/Intelligence/GeneratedAutomationProposal.swift`
- Criado: `Sources/Tico/Services/Intelligence/LocalIntelligenceService.swift`
- Criado: `Sources/Tico/Services/Intelligence/LocalIntelligenceServicing.swift`
- Criado: `Sources/Tico/Views/Components/Content/ContentTextTransformationView.swift`
- Criado: `Sources/Tico/Views/Components/Describe/AutomationIntelligenceSession.swift`
- Criado: `Sources/Tico/Views/Components/Describe/AutomationProposalView.swift`
- Criado: `Sources/Tico/Views/Components/Describe/NaturalAutomationView.swift`
- Criado: `outputs/foundation-models-local.md`

## Referências

- [Foundation Models](https://developer.apple.com/documentation/foundationmodels)
- [Geração guiada](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation)
- [Contexto do modelo local](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window)
