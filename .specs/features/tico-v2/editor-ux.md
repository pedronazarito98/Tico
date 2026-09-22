# Refatoração do editor de atalhos

16/09/2026 — pedido explícito para reduzir passos, selects e dificuldade na tela
Meus atalhos. Implementação incremental sobre o working tree da V2, preservado.

## Resultado

- Uma página com resumos Quando → Fazer → Onde. Um bloco expandido por vez, em
  qualquer ordem; salvar continua no rodapé fixo. Não há sequência obrigatória de telas.
- Gesto por escolhas visuais, quantidade de dedos em botões e gravação em destaque.
  Editor técnico, sequências, trajetórias e ajustes existentes continuam acessíveis.
- Nomes de teclas no resumo usam o layout atual do macOS. Carbon fica em um serviço
  síncrono estreito; nenhuma captura, log ou alteração do gatilho é feita por ele.
- Catálogo de ações pesquisável, separado entre uso cotidiano e automação avançada.
  Operações comuns de janela são escolhas visuais; aplicativos podem ser pesquisados.
- Ações em cartões ordenados, com expansão individual. Uma ação única dispensa a
  lista lateral, a numeração e o cabeçalho duplicado. Adicionar exige escolher uma ação.
- Atraso, timeout, nome e ativação da etapa ficam em Ajustes desta ação. Biblioteca,
  política de erro e limite total permanecem acessíveis sob demanda.
- Contexto com busca e seleção de múltiplos apps; associações importadas são preservadas.
  Perfil, condições, prioridade e notas ficam nas opções avançadas, com resumo.
- Reverter, modelos e exclusão ficam em Mais opções; Salvar atalho é a ação principal.
- Avisos de nome, contexto e ações incompletas acompanham o estado do botão Salvar.
  Link inválido em qualquer ação ativa bloqueia o salvamento, inclusive se recolhida.

## Decisões técnicas e paralelo com React

RuleEditingSession continua dono do draft. Componentes recebem Binding, valores e
callbacks; identidade das etapas continua baseada em UUID. Esconder controles não
desmonta o draft local de URL. Os blocos recolhidos são removidos da árvore de
acessibilidade e desabilitados para interação, mantendo seu estado em memória.

Paralelo com React: estado elevado no editor e componentes controlados. A seção
aberta é estado de apresentação, separado dos dados salvos. O serviço de nomes de
teclas consulta uma API nativa sem equivalente direto em React no navegador.

Sem alteração de schema, formato dos workflows, executor, reconhecimento de gestos
ou dependências. A tela de cenas recebe o mesmo editor compartilhado e a mesma
validação de ações. Nenhum teste, mock ou fixture novo foi criado.

## Verificação observada

| Verificação | Resultado |
| --- | --- |
| Build SwiftPM via Command Line Tools | PASS; último empacotamento compilou em 3,24 s |
| `build_and_run.sh --package` com CLT | PASS: app, ZIP, DMG, assinatura ad hoc, checksum |
| `git diff --check` | PASS após corrigir uma linha vazia excedente |
| `swift test --disable-sandbox` com CLT | BLOCKED: `no such module 'XCTest'`, nenhum teste executado |
| Gate canônico `ci_verify.sh --package` | BLOCKED exit 69: licença do Xcode; sintaxe inicial dos scripts PASS |
| Interface nativa em dados isolados | PASS nos fluxos abaixo |

Fluxos executados por acessibilidade e captura visual, com regras sintéticas
desativadas e execução real bloqueada pelo modo de UI testing:

1. Criar regra; editar nome, gesto e dedos; alternar blocos preservando as escolhas.
2. Pesquisar “janela”, trocar notificação por organização de janela e selecionar Maximizar.
3. Selecionar contexto específico: vazio bloqueia salvar; buscar Safari e selecionar libera.
4. Salvar desativada; adicionar link como segunda ação; URL `https://` bloqueia salvar.
5. Recolher/reabrir preserva texto inválido; corrigir URL, reordenar e salvar sequência.
6. Encerrar/reabrir a instância isolada e observar nome, gesto, contexto e duas ações persistidos.
7. Alterar URL e Reverter: endereço salvo e estado limpo recuperados.
8. Validar que os controles recolhidos não aparecem mais na árvore de acessibilidade.
9. Redimensionar a janela: conteúdo continua acessível por rolagem e rodapé permanece visível.
10. Verificar uma ação única compacta e o popover de busca/seleção do aplicativo.
11. Observar `⌘⇧ S` no lugar de `⌘⇧ Tecla 1` no resumo do editor.

## Limites

Inspeção visual em dark mode concluída. Uma tentativa de aparência clara por argumento
de lançamento não mudou o tema observado; light mode permanece NOT-RUN, apesar dos
tokens adaptativos preservados. VoiceOver completo, gestos físicos e todos os campos
avançados em combinação permanecem NOT-RUN. Nenhuma permissão TCC foi concedida.

O usuário precisa concluir a licença do Xcode antes de repetir a suíte e o gate.
Não houve commit, push, PR, publicação ou aceite de licença nesta tarefa.

## Arquivos desta refatoração

Modificados: `Views/RuleEditorView.swift`, `Views/WorkflowEditorView.swift`,
`Views/RuleActionEditorView.swift`, `Views/RuleContextEditorView.swift`,
`Views/SceneEditorView.swift`, `Views/Components/Rules/RuleEditingSession.swift` e
`Views/Components/Rules/RuleEditorFooterView.swift`.

Criados em `Sources/Tico/Views/Components/Rules`: `RuleComposerSection.swift`,
`EditorChoiceButton.swift`, `RuleEditorSummary.swift`, `RuleTriggerComposerView.swift`,
`RuleActionKind.swift`, `RuleActionPickerView.swift`, `RuleScopeComposerView.swift`,
`WindowActionChoices.swift`, `WorkflowEditorValidation.swift`, `WorkflowStepCard.swift`
e `ApplicationSearchPicker.swift`. Serviço: `Sources/Tico/Services/KeyboardLabelService.swift`.
README e este relatório documentam a mudança.
