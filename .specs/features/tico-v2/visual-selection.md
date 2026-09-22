# Seleção visual de ações e aplicativos

Implementado e validado em 17/09/2026. Escopo: reduzir decisões intermediárias
no editor nativo existente, preservando tabela, inspetor e materiais do macOS.

## Comportamento

- A galeria recebe aplicações e entrega `ShortcutAction` completo. Clicar em
  Safari configura Abrir Safari, sem selecionar primeiro um tipo e depois um app.
  Busca aceita Safari e abrir Safari. Cancelar não modifica o rascunho.
- Apps aparecem com seus ícones reais, obtidos pelo NSWorkspace em um serviço
  estreito. Não são abertos para obter o ícone, nem têm documentos acessados.
- Busca e alternativas ficam inline no inspetor. Inicialmente há seis opções,
  priorizando apps em execução; Ver todos expande o catálogo e a busca considera
  todos os apps. A consulta não modifica o aplicativo selecionado.
- Escopo usa o mesmo navegador em seleção múltipla, com nomes, ícones e remoção
  individual. Alvo de ação distingue App em uso de Escolher app.
- Operações de aplicativo são botões visíveis. Escolher Abrir a partir de App em
  uso exige selecionar explicitamente um app; nenhum app arbitrário é atribuído.
- Posições de janela têm miniaturas proporcionais. Metades, terços e quartos
  continuam disponíveis, com expansão inline das opções menos comuns.
- Copiar seleção, Colar, Desfazer e Selecionar tudo estão disponíveis diretamente
  na galeria e no editor. Personalizar combinação preserva o ajuste técnico.
- Atalhos do macOS têm busca/entrada por nome e resultados clicáveis. Operações
  contínuas e resposta ao movimento apresentam opções visíveis.
- Ajustes de sequência conservam as políticas existentes em opções de rádio.
- A validação impede salvar um alvo específico vazio. Regras persistidas e
  execução de ações mantêm os mesmos modelos e serviços.

## Arquivos desta rodada

Criados:

- `Sources/Tico/Services/ApplicationIconService.swift`
- `Sources/Tico/Views/Components/Rules/ApplicationIconView.swift`
- `Sources/Tico/Views/Components/Rules/ApplicationChoiceGrid.swift`
- `Sources/Tico/Views/Components/Rules/ApplicationBrowserView.swift`
- `Sources/Tico/Views/Components/Rules/ApplicationOperationChoices.swift`
- `Sources/Tico/Views/Components/Rules/WindowPlacementPreview.swift`
- `Sources/Tico/Views/Components/Rules/KeyboardActionChoices.swift`
- `Sources/Tico/Views/Components/Rules/KeyboardActionPreset.swift`
- Este registro.

Alterados:

- `Sources/Tico/Views/ApplicationPickerView.swift`
- `Sources/Tico/Views/RuleActionEditorView.swift`
- `Sources/Tico/Views/WorkflowEditorView.swift`
- `Sources/Tico/Views/Components/Rules/ApplicationSearchPicker.swift`
- `Sources/Tico/Views/Components/Rules/RuleActionPickerView.swift`
- `Sources/Tico/Views/Components/Rules/RuleScopeComposerView.swift`
- `Sources/Tico/Views/Components/Rules/WindowActionChoices.swift`
- `Sources/Tico/Views/Components/Rules/WorkflowEditorValidation.swift`
- `Sources/Tico/Views/Components/Rules/RuleEditorSummary.swift`
- `Sources/Tico/Views/Components/Rules/WorkflowStepCard.swift`
- `README.md`

Os demais arquivos modificados/untracked pertenciam ao trabalho anterior e foram
preservados. Não foram criados testes, mocks ou fixtures.

## Paralelo com React

O Binding equivale à fronteira de um componente controlado: o editor mantém a
seleção e os componentes recebem valores e closures. Busca e expansão usam State
local. A galeria entrega a ação completa ao owner; não mantém um segundo rascunho.
O carregamento do ícone usa task(id:) ligada à identidade da URL, com AppKit
restrito ao serviço de plataforma. Não foi acrescentada dependência.

## Evidência executada

| Verificação | Resultado |
| --- | --- |
| Build SwiftPM via Command Line Tools | PASS |
| Pacote final via build_and_run.sh --package | PASS, compilação 4,36 s; app, ZIP e DMG com validação ad hoc pelo script |
| git diff --check | PASS |
| swift test --disable-sandbox via CLT | BLOCKED: no such module XCTest, antes de executar testes |
| ci_verify.sh --package | BLOCKED: licença do Xcode, exit 69; sintaxe dos scripts passou |

UI observada em cópia temporária usando --ui-testing, dados, defaults e home
isolados. Captura permaneceu pausada, todas as regras desativadas e efeitos reais
bloqueados pelo modo existente. Sem concessão de TCC ou alteração de tema do Mac.

Cenários observados:

1. Substituir notificação por Abrir Chrome em um clique na galeria.
2. Buscar Safari no inspetor e trocar o aplicativo sem outro seletor.
3. Escolher contexto específico vazio bloqueia Salvar; selecionar Safari libera.
4. Salvar atualiza o nome da regra e o contexto na tabela.
5. Adicionar ação de janela mantém a ação de app e seleciona metade esquerda.
6. Escolher alvo específico vazio bloqueia Salvar; escolher Safari libera.
7. Expandir posições, selecionar quarto superior direito, recolher e salvar.
8. Cancelar galeria por Escape preserva a ação salva.
9. Reabrir app preserva Abrir Safari, posição superior direita e escopo Safari.
10. Selecionar Copiar no editor configura Command+C; selecionar Copiar seleção
    diretamente na galeria também entrega Command+C.
11. Trocar para Ocultar exibe quatro operações; selecionar Abrir exige app.
12. Reverter remove a terceira ação temporária e restaura a sequência salva.
13. Busca abrir Safari retorna a ação correspondente no pacote final.
14. Busca sem resultados mostra orientação em português; rolagem revela as demais
    ações; o texto lido pela acessibilidade usa nomes de apps, não bundle IDs.
15. Capturas reais do inspetor e da galeria inspecionadas em aparência clara.

## Validação manual restante

VoiceOver completo, aparência escura nesta rodada, catálogo real de Atalhos do
macOS (vazio por isolamento), layouts de teclado alternativos, gestos físicos e
execução real das ações não foram validados. A edição técnica de combinações
personalizadas ainda usa códigos de tecla dentro da seção avançada.

A licença do Xcode não foi aceita automaticamente. Não houve commit, push,
publicação ou instalação em Aplicativos. Pacote local em dist/Tico.app.
