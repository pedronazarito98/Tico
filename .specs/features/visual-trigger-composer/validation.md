# Validação do criador visual de acionamentos

Data: 29/09/2026. Plataforma observada: macOS 27, Xcode 27, Swift 6.4, Apple Silicon. Deployment target preservado: macOS 26+.

## Resultado

**PASS — gate automatizado completo e cenários nativos descritos abaixo.**

**PARTIAL — validação em dispositivo:** trackpad físico, concessão real de permissões, VoiceOver, Reduzir Movimento nas preferências do sistema e execução real de automações não foram exercitados. Esses resultados não são inferidos de build, testes unitários ou animações demonstrativas.

## Comandos executados

| Verificação | Resultado observado |
| --- | --- |
| `git diff --check` | PASS |
| `swift build --disable-sandbox --product Tico` | PASS |
| `swift test --disable-sandbox` | PASS: 128 testes, zero falhas |
| `TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package` | PASS: execução final com exit code 0 |
| Xcode Debug + assinatura strict/deep | PASS, incluído no gate |
| Archive Release para arm64 e x86_64, hardened runtime | PASS, incluído no gate |
| XCUITest existente de criação e persistência | PASS, incluído no gate |
| Reexecução da suíte de segurança | PASS: 8 testes, zero falhas; fazem parte dos 128 testes, não são 8 casos novos |
| Pacote local ad hoc, ZIP e DMG | PASS: integridade, assinatura e preflight |

A primeira execução do XCUITest falhou na inicialização do runner, com timeout ao habilitar automação, antes do cenário. A execução isolada seguinte passou. Depois dos últimos ajustes, o gate completo também passou. O Xcode emitiu diagnóstico de descoberta de debugger (`noURL`), sem falha na execução final. O `hdiutil` emitiu aviso de depreciação do comando de montagem; a verificação do DMG terminou com checksum válido.

Nenhum teste novo, mock ou fixture foi criado. O teste existente em `Xcode/TicoUITests/FirstShortcutUITests.swift` foi atualizado para navegar pelas três etapas, capturar Command + Option + S, salvar pausado e confirmar a persistência após relançar. As verificações de criação, contagem, estado pausado e persistência foram mantidas.

## Inspeção nativa isolada

App de QA: `/private/tmp/TicoComposerQA/Tico QA.app`. Bundle e diretório de dados separados da instalação do usuário. O modo `--ui-testing` desabilita a execução de ações reais; a captura global permaneceu pausada. Não foram alteradas permissões TCC nem a aparência global do macOS.

| Cenário | Resultado |
| --- | --- |
| Selecionar Centralizar janela, configurar acionamento e revisar | PASS |
| Gravar Command + Option + S e manter a combinação após soltar | PASS |
| Regravar Command + Option + D e depois S | PASS |
| Encerrar gravação com Escape | PASS |
| Escolher tecla e modificadores no desenho | PASS |
| Prática: entrada diferente mostra Recebido e Esperado | PASS |
| Prática: entrada correta mostra Funcionou e prévia segura | PASS |
| Montar duas etapas, reordenar, editar e confirmar atualização | PASS |
| Prática da sequência Command + Option + D → Command + Option + S | PASS: reconhecimento pelo matcher existente |
| Escopo: selecionar Safari, fechar popover com Escape e manter seleção | PASS |
| Salvar sequência pausada, relançar e verificar persistência | PASS |
| Duplicar como rascunho independente e pausado | PASS |
| Descartar duplicação sem acrescentar regra à biblioteca | PASS |
| Editar nome, descartar e reabrir com nome original | PASS no pacote final |
| Fechar editor sem alterações | PASS, sem confirmação desnecessária |
| Conflito exato: aviso na revisão e decisão explícita ao salvar | PASS |
| Conflito: Alterar acionamento retorna ao gravador | PASS |
| Substituir regra pela opção destrutiva | NOT-RUN na inspeção manual; lógica existente preservada |
| Mouse: captura local do clique do meio | PASS |
| Mouse: seleção clicando na roda desenhada | PASS |
| Trackpad: escolha de gesto/dedos e modificadores | PASS na configuração visual |
| Trackpad: combinação exige modificadores para confirmar | PASS na configuração visual |
| Trackpad: iniciar/pausar demonstração | PASS; demonstração identificada na interface |
| Permissão indisponível: explicação e botão Abrir Ajustes | PASS visual; não foi concedida permissão |
| Personalizado: três amostras vazias e confirmação indisponível | PASS visual |
| Personalizado: gravar e regravar trajetória com dedos físicos | NOT-RUN |
| Tema claro e tema escuro em teclado e mouse | PASS visual |
| Árvore de acessibilidade com nomes, estados e identificadores dos controles | PASS na inspeção AX |
| VoiceOver, texto ampliado e Reduzir Movimento no sistema | NOT-RUN |

Na automação por acessibilidade, um botão acionado sem ativar a janela pode iniciar a sessão sem entregar eventos locais. O cenário foi repetido com clique direto na janela: captura e regravação funcionaram. O monitor continua restrito à janela que iniciou a gravação. O XCUITest final também percorreu a captura local com sucesso.

## Artefatos

- App: `dist/Tico.app`
- ZIP: `dist/Tico.zip`
- DMG: `dist/Tico.dmg`
- Evidências visuais: `$CODEX_HOME/visualizations/2026/09/29/01a0ed93-32e0-7510-94f7-65568c2480aa/tico-implementacao/`
- Comparação com a referência: `design-qa.md` na raiz.

O archive Release universal e os pacotes locais são verificações distintas. Os pacotes em `dist` são ad hoc para desenvolvimento; não há alegação de Developer ID, notarização, aceitação por Gatekeeper ou execução em uma máquina limpa. Nenhum commit, push, PR ou publicação foi feito.

## Limites do contrato preservado

- Um atalho de teclado combina uma tecla não modificadora com modificadores. Acordes como A + S + D simultâneos não foram adicionados. O gravador orienta o usuário a usar sequência para entradas em ordem.
- A combinação com trackpad usa Command, Option, Control ou Shift com um gesto predefinido. Letras mantidas com gesto e gesto livre personalizado com modificadores continuam fora do contrato existente.
- Sequências aceitam de duas a cinco entradas em ordem, incluindo dispositivos diferentes.
- Botão do meio e botões extras do mouse são suportados. Rolagem e cliques primários não foram apresentados como gatilhos disponíveis.
- Captura local de teclado/mouse funciona dentro da janela. Reconhecimento global ainda depende das permissões do macOS.
- O modo compatível de trackpad possui limitações para contatos, trajetórias e regiões; a interface informa isso.

## Roteiro manual restante

1. Em uma instalação de desenvolvimento, gravar gesto com três dedos; verificar contatos/traço, soltar e confirmar a seleção.
2. Segurar Option + Command enquanto faz o gesto. Verificar captura, prática segura e reconhecimento global após as permissões necessárias.
3. Gravar três trajetórias personalizadas, regravar apenas a segunda, salvar, reabrir e comparar as amostras preservadas.
4. Experimentar sequência que alterna teclado e trackpad, inclusive o intervalo limite e entrada incorreta.
5. Verificar concessão/negação de Monitoramento de Entrada e Acessibilidade, encerramento/reabertura e sleep/wake.
6. Percorrer o fluxo com VoiceOver, navegação por teclado, Reduzir Movimento e configurações maiores de texto/tela.

## Arquivos envolvidos

### Criados

- `Sources/Tico/Services/LocalInputCaptureService.swift`
- `Sources/Tico/Support/InputPresentation.swift`
- `Sources/Tico/Views/Components/Rules/Composer/TriggerCaptureSession.swift`
- `Sources/Tico/Views/Components/Rules/Composer/TriggerCaptureEditor.swift`
- `Sources/Tico/Views/Components/Rules/Composer/VisualKeyboardView.swift`
- `Sources/Tico/Views/Components/Rules/Composer/TrackpadCaptureVisual.swift`
- `Sources/Tico/Views/Components/Rules/Composer/MouseCaptureVisual.swift`
- `Sources/Tico/Views/Components/Rules/Composer/TriggerSequenceTimeline.swift`
- `Sources/Tico/Views/Components/Rules/Composer/ComposerReviewStep.swift`
- `Sources/Tico/Views/Components/Rules/Composer/KeyboardShortcutPicker.swift`
- `.specs/features/visual-trigger-composer/design.md`
- `.specs/features/visual-trigger-composer/validation.md`
- `design-qa.md`

### Modificados

- `Sources/Tico/App/TicoApp.swift`
- `Sources/Tico/Support/AppController.swift`
- `Sources/Tico/Support/DisplayText.swift`
- `Sources/Tico/Support/GesturePracticeSession.swift`
- `Sources/Tico/Views/ShortcutComposerView.swift`
- `Sources/Tico/Views/ContentView.swift`
- `Sources/Tico/Views/RulesView.swift`
- `Sources/Tico/Views/SequenceEditorView.swift`
- `Sources/Tico/Views/Components/Rules/RuleEditorSummary.swift`
- `Sources/Tico/Views/Components/Rules/RuleTriggerEditorView.swift`
- `Sources/Tico/Views/Components/Rules/RuleWorkspaceSession.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutActionCatalogView.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutLibraryDetailView.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutScopePicker.swift`
- `Xcode/TicoUITests/FirstShortcutUITests.swift`
- `script/build_and_run.sh`

O script de empacotamento recebeu apenas compatibilidade com o bundle de recursos estruturado do SwiftPM/Xcode 27. `TicoApp` recebeu uma opção de tema escuro restrita à execução isolada de QA. Não foram adicionadas dependências nem feita migração de dados.
