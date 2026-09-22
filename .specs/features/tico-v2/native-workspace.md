# Meus atalhos: tabela e inspetor nativos

16/09/2026. Implementação autorizada após a escolha da opção 3 e o refinamento
visual com Liquid Glass. Incremental sobre as alterações locais da V2.

## Interface entregue

- `Table` nativa com seleção por UUID, teclado, ativação por linha e menu contextual.
- Busca na tabela por nome, acionamento e aplicativo; filtro Todos/Trackpad/Teclado/Mouse.
  Sequências aparecem nos filtros dos dispositivos presentes em suas etapas.
- Navegação estável: Todos os atalhos, Explorar, Cenas, Mapa de gestos, aplicativos
  associados explicitamente às regras e ferramentas recolhíveis. Ajustes abre a cena
  nativa existente. A busca não substitui o conteúdo da barra lateral.
- `.inspector` redimensionável e ocultável, com acionamento, ações e escopo.
- Gravação existente preservada; editor técnico em popover, sem campos de código de
  tecla ou ajustes avançados ocupando a tela principal.
- Quatro posições comuns de janela visíveis, outras operações no menu existente.
- Seleção múltipla de apps em popover pesquisável. Contexto vazio bloqueia salvar.
- Perfis, condições, prioridade, notas, presets, biblioteca, sequência de ações,
  conflitos e reversão continuam acessíveis. Salvar é explícito, também por `⌘S`.
- Rascunhos permanecem na janela enquanto se alternam regras, filtros e seções.
  Não são persistidos automaticamente nem recuperados após encerrar o app.

## Materiais e adaptação da referência

A implementação usa `NavigationSplitView`, `Table`, `.inspector`, toolbar e controles
SwiftUI do macOS 26. Não há wallpaper, camada de blur ou vidro desenhado para simular
uma captura. O material nativo varia com aparência, fundo e preferências do sistema.
O botão de salvar usa `.glassProminent`; a toolbar mantém agrupamentos nativos.

A imagem aprovada foi usada para a hierarquia de três áreas e edição contextual.
A densidade real segue controles de desktop. As seções existentes da V2 foram
preservadas; Favoritos não foi inventado como funcionalidade. O botão Praticar testa
reconhecimento, sem executar ações, conforme o fluxo existente.

## Estado e paralelo com React

`ContentView` é dona de `RuleWorkspaceSession` via `@StateObject`. O workspace mantém
`RuleEditingSession` por UUID. O inspetor observa a sessão com `@ObservedObject` e seus
filhos recebem `Binding`. O store continua dono dos valores persistidos.

Paralelo com React: estado elevado ao pai e campos controlados permitem trocar o
item selecionado sem perder o formulário. `@SceneStorage` preserva apenas preferências
de apresentação por janela. `Table`, `.inspector` e Liquid Glass são componentes e
materiais do sistema; não correspondem a CSS ou a componentes HTML.

## Verificação executada

| Gate | Resultado |
| --- | --- |
| `swift build --disable-sandbox --product Tico` via CLT | PASS |
| `build_and_run.sh --package` via CLT | PASS; compilação final 2,88 s, app/ZIP/DMG e assinatura ad hoc verificados pelo script |
| `git diff --check` | PASS |
| `swift test --disable-sandbox` via CLT | BLOCKED antes de executar testes: `no such module 'XCTest'` |
| `TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package` | BLOCKED exit 69: licença do Xcode; sintaxe dos scripts passou |
| UI nativa com dados isolados | PASS nos cenários descritos abaixo |
| Reprodução pixel a pixel da imagem gerada | Não é o critério: controles e materiais são os nativos do sistema |

A cópia de validação usou `--ui-testing`, diretório `TicoUITests-*`, preferências e
home temporários. Execução de automações reais foi bloqueada pelo modo existente.
Nenhum teste, mock ou fixture foi criado; nenhuma permissão TCC foi concedida.

Cenários observados por acessibilidade e screenshot:

1. Criar regra desativada; renomear; trocar de linha e retornar preserva rascunho.
2. Trocar teclado por gesto de três dedos à esquerda no popover técnico.
3. Selecionar Organizar janela, escolher a posição e selecionar Safari com busca.
4. Contexto específico vazio desabilita Salvar; selecionar Safari habilita.
5. Salvar atualiza tabela e acrescenta Safari à navegação; reabrir preserva dados.
6. Filtros por Trackpad e Safari retornam o atalho esperado.
7. Criar uma regra de teclado sob filtro Trackpad retorna a Todos e exibe a nova regra.
8. Buscar por nome, observar estado sem resultados e limpar busca sem duplicar navegação.
9. Ocultar/reabrir inspetor mantém a seleção; setas navegam pelas linhas.
10. Alterar nome, ir a Explorar e voltar preserva rascunho; Reverter restaura valor salvo.
11. Aparências escura e clara inspecionadas. Clara foi forçada somente no Info.plist da
    cópia temporária, sem modificar tema do Mac ou metadados do app distribuído.
12. Reduzir/ampliar janela mantém controles acessíveis e rodapé visível; conteúdo extenso
    ganha rolagem nativa. Sobreposição inicial de Ajustes/status foi corrigida.

## Limites e validação manual restante

Trackpad físico, execução de ações de janela, TCC, VoiceOver completo, combinações de
condições avançadas e múltiplas janelas simultâneas não foram validados nesta rodada.
Esses itens não são comprovados por build ou screenshot. O efeito de vidro deve ser
avaliado também sobre o wallpaper e com as preferências de acessibilidade do usuário.

O gate completo precisa do Xcode com licença aceita e XCTest disponível. Não houve
commit, push, PR, publicação ou aceite de licença.

## Arquivos desta implementação

Criados em `Sources/Tico/Views/Components/Rules`:

- `RulesTableView.swift`
- `RuleInputFilter.swift`
- `RuleInspectorTriggerView.swift`
- `RuleWorkspaceSession.swift`

Alterados:

- `Sources/Tico/App/TicoApp.swift` — tamanho inicial da janela.
- `Sources/Tico/Views/ContentView.swift` — composição, workspace por janela e busca.
- `Sources/Tico/Views/SidebarView.swift` — navegação estável e aplicativos.
- `Sources/Tico/Views/RulesView.swift` — tabela, seleção, filtros e inspetor.
- `Sources/Tico/Views/RuleEditorView.swift` — composição compacta do inspetor.
- `Sources/Tico/Views/RuleActionEditorView.swift` — tipografia compacta.
- `Sources/Tico/Views/Components/Rules/RuleEditingSession.swift` — sincronização preservando rascunho.
- `Sources/Tico/Views/Components/Rules/RuleEditorHeaderView.swift` — cabeçalho compacto.
- `Sources/Tico/Views/Components/Rules/RuleEditorFooterView.swift` — prática e salvar com vidro nativo.
- `Sources/Tico/Views/Components/Rules/RuleEditorSummary.swift` — símbolos de acionamento.
- `Sources/Tico/Views/Components/Rules/RuleScopeComposerView.swift` — escopo e seleção contextual de apps.
- `Sources/Tico/Views/Components/Rules/WindowActionChoices.swift` — posições em quatro colunas.
- `README.md` e este registro.

Os demais arquivos modificados/untracked já pertenciam ao trabalho anterior da V2.
