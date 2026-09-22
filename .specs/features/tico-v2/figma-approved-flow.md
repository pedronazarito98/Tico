# Tico V2 — fluxo aprovado no Figma

Implementação de 20/09/2026, autorizada pelo pedido de analisar e implementar
integralmente a página [03 · V2 aprovada · Light](https://www.figma.com/design/He5DWR8GX4jF7iXhYTOrg0/Tico---Telas-reais-e-fluxo-de-usuario?node-id=3121-2).
Incremental sobre o trabalho local da V2, sem commit, publicação ou novas dependências.

## Fonte e escopo

As dez telas foram lidas por `get_design_context`, incluindo suas imagens e as
anotações da página. O arquivo preserva conceitos rasterizados, sem componentes
internos ou tokens por controle. A implementação reconstrói as interações em SwiftUI
com controles nativos, ícones reais dos apps instalados e tokens adaptativos do Tico.

A prévia de resultado é uma cena ilustrativa local, com janela e posições calculadas.
Não captura o desktop, não abre Safari e não embute a imagem inteira do mockup como UI.
O wallpaper e a fotografia decorativa da referência não são assets independentes;
a prévia usa uma composição de cores da marca. Não se declara equivalência pixel a pixel.

| Tela | Implementação |
| --- | --- |
| 01 · Escolher a ação | Busca por palavras e acentos, apps instalados, posições de janela, galeria completa e prévia |
| 02 · Gravar o gesto | Contagem de dedos e trajetória, indicação de direção, aceitação ao soltar; cancelamento não aceita gesto parcial |
| 03 · Experimentar | Prática contínua integrada à prévia; reconhecimentos reais animam o resultado sem executar workflows |
| 04 · Revisar e criar | Gesto → ação, escopo, ajustes opcionais, validação e confirmação de conflitos |
| 05 · Atalho criado | Retorno à biblioteca com seleção, confirmação, ativação, escopo, experimentar e editar |
| 06 · Escolher aplicativos | Popover com busca, seleção múltipla, ícones e Aplicar; escopo específico vazio é inválido |
| 07 · Mais ajustes | Nome, nota opcional, Na hora/Após pausa, disponibilidade e Restaurar padrões |
| 08 · Avançado | Perfil, prioridade, tempo máximo e condições recolhidos por padrão |
| 09 · Adicionar condição | Escolha de horário, monitor conectado, título da janela ou modificadores |
| 10 · Configurar horário | Dias independentes, início/fim, resumo e confirmação; condição existente pode ser editada |

## Decisões e continuidade

- `RuleEditingSession` continua sendo a fonte de verdade do rascunho. Flags de escolha
  impedem que ação/gesto iniciais do modelo sejam tratados como decisões do usuário.
- Criar só grava no store após validação e clique explícito. O atalho novo fica ativo,
  conforme a tela aprovada, mas criar não inicia captura global nem executa a ação.
  A instalação de receitas/descritivos continua desativada no fluxo preexistente.
- Edições não salvas permanecem na sessão ao fechar o editor e trocar de seleção.
  A criação cancelada é descartada. O comando Reverter permanece no menu do editor.
- Substituir conflitos durante criação usa uma única operação atômica do store,
  com rollback; não há criação intermediária seguida de exclusões separadas.
- A pausa é `delayBefore` da primeira etapa habilitada. O tempo máximo usa o timeout
  do workflow; Automático restaura os 60 segundos existentes. Nenhum schema mudou.
- Prioridades simples mapeiam para -5/0/5; valores existentes diferentes continuam
  representados. Perfis desativados não são removidos silenciosamente da seleção.
- A prática guiada continua em três repetições. O criador usa o mesmo reconhecimento
  sem limite até Encerrar teste. Um token impede encerrar a prática de outra janela.
- Encerrar, cancelar ou fechar o criador libera sua captura e restaura o estado
  anterior pelo controller existente. Ações de automação não entram na prévia.
- Teclado, mouse, gesto personalizado, sequências, modelos e ações avançadas continuam
  disponíveis. O editor completo anterior permanece no menu contextual da biblioteca.
- O serviço de monitores concentra AppKit; as views recebem apenas escolhas tipadas.
  Identificadores não aparecem em rótulos, evidência ou documentação.

## Paralelo com React

`@StateObject` mantém o workspace por janela e `@ObservedObject` observa a sessão.
Isso se aproxima de elevar o estado do formulário a um pai e passar campos controlados.
`Binding` permite editar o mesmo rascunho sem duplicá-lo. Popovers usam estado local
e só confirmam mudanças ao clicar em Aplicar/Adicionar. O popover de condições usa
um item identificável com seu payload, evitando abrir uma edição com dados antigos.

SwiftUI não usa DOM ou CSS: o sistema negocia layout, foco, materiais e controles.
Capture e IO permanecem nas fronteiras existentes; as views recebem callbacks.

## Verificação

| Verificação | Resultado observado |
| --- | --- |
| `git diff --check` | PASS |
| Build SwiftPM com CLT, SDK 26.5 e motor nativo | PASS |
| Suíte existente executada diretamente pelo runner `xctest` | PASS: 128 testes, 0 falhas; inclui 8 testes de segurança |
| `build_and_run.sh --package` com a mesma seleção de SDK/motor | PASS: `.app`, ZIP, DMG, assinatura ad hoc e verificação do DMG |
| Comando canônico de CI | BLOCKED: licença do Xcode, exit 69; verificação de sintaxe dos scripts passou |
| `swift test` somente com CLT | BLOCKED: `no such module 'XCTest'` |
| XCUITest nativo | NOT-RUN: depende do ambiente Xcode |
| Inspeção visual do tema escuro | NOT-RUN: override da cópia isolada permaneceu claro; tema do sistema preservado |
| Captura física, TCC, execução real, múltiplos monitores | NOT-RUN nesta rodada |
| Developer ID/notarização | NOT-RUN; pacote local ad hoc |

O Swift 6.4 instalado usa `swiftbuild` por padrão; nesse ambiente ele não encontrou
`SwiftUIMacros.StateMacro` do SDK padrão. Foi usado o SDK 26.5 instalado e o motor
`native`, sem modificar Package.swift ou aceitar a licença do Xcode:

```bash
DEVELOPER_DIR=/Library/Developer/CommandLineTools swift build \
  --disable-sandbox --build-system native \
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk --product Tico
```

Para a suíte, a compilação `swift build --build-tests` usou os mesmos flags mais
`-F` para `MacOSX.platform/Developer/Library/Frameworks`, `-I`/`-L` para
`MacOSX.platform/Developer/usr/lib` e respectivos rpaths, sob o Xcode instalado.
O comando `swift test --filter` compilou mas reportou zero testes nesse ambiente;
esse resultado NÃO foi contado como aprovação. A execução verificada foi:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xctest \
  .build/arm64-apple-macosx/debug/TicoPackageTests.xctest
```

O pacote foi produzido pelo script existente com uma função de shell temporária
encaminhando suas chamadas `swift` aos mesmos flags de SDK/motor. Não foi alterado
o pipeline do projeto nem incluído workaround de ambiente no código de produto.

### Interface real

Cópia do `.app` em diretório temporário `TicoUITests-*`, com `--ui-testing`, home,
preferências e dados isolados. Nenhuma regra pessoal foi lida ou executada.

Cenários observados:

1. Criador começa com Experimentar/Criar desabilitados.
2. Busca “janela à esquerda” encontra a posição; selecionar atualiza a prévia.
3. Escolher explicitamente gesto de três dedos habilita Criar.
4. Escopo específico vazio desabilita Aplicar; seleção Safari/Finder é confirmada.
5. Nome, Após pausa e condição segunda–sexta 09:00–18:00 são aplicados.
6. Criar seleciona o atalho na biblioteca e mostra a confirmação.
7. Abrir um segundo rascunho e cancelar mantém a contagem da biblioteca.
8. Encerrar e reabrir o app preserva regra, nome, ativação, escopo, pausa e condição.
9. Editar uma condição carrega dias e horários existentes. Desmarcar todos os dias
   desabilita Salvar; cancelar preserva a condição anterior.
10. A coluna estreita troca os segmentos por um menu, sem cortar opções. Selecionar
    Teclado mostra um atalho; retornar a Todos restaura os três atalhos sintéticos.
11. No criador de 960 × 680, as ações iniciais, Todas as ações e gravação do gesto
    ficam visíveis simultaneamente após os ajustes finais de espaçamento.

## Pontos de atenção e validação manual

- Validar a gravação com trackpad físico, incluindo gesto cancelado, hold, fallback
  e liberação dos contatos; build/replay não comprovam essa fronteira.
- Repetir gestos na prévia e verificar que nenhuma ação real acontece. Validar
  restauração da captura anterior, cancelamento e exclusão mútua entre janelas.
- Validar execução real de ações, perfis, prioridades concorrentes, monitor,
  horários que atravessam meia-noite, tema escuro, VoiceOver e Reduce Motion no Mac de uso.
- O teste XCUITest preexistente descreve o fluxo antigo de criação desativada.
  Sua expectativa precisa ser reconciliada com a criação ativa aprovada antes de
  usar esse cenário como gate do novo fluxo. Nenhum teste/assertion foi alterado.
- Nenhum teste, mock ou fixture foi criado. Os 128 testes existentes não representam
  cobertura automatizada específica de todas as interações novas.

## Arquivos desta alteração

Criados:

- `Sources/Tico/Views/ShortcutComposerView.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutActionCatalogView.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutActionIcon.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutConditionPicker.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutConditionSummary.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutGesturePreview.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutGestureRecorder.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutLibraryDetailView.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutOptionsView.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutResultPreview.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutScopePicker.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutTriggerPicker.swift`
- `Sources/Tico/Services/DisplayCatalogService.swift`
- Este documento.

Alterados sobre o trabalho local existente:

- `RuleEditingSession.swift`, `RuleWorkspaceSession.swift`, `GesturePracticeSession.swift`.
- `ShortcutStore.swift`, `AppController.swift`.
- `ContentView.swift`, `RulesView.swift`, `SidebarView.swift`, `README.md`.

Demais arquivos já modificados/untracked pertencem ao trabalho anterior e foram preservados.
