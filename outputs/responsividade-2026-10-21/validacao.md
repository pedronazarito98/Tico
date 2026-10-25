# Responsividade do Tico — 21/10/2026

## Contrato de layout

- Janela principal com conteúdo mínimo de 680 × 480 pontos. Primeira abertura limitada pela área útil do display; o macOS restaura dimensões escolhidas posteriormente.
- Sheets usam a área oferecida pela janela, com margem de 32 pontos na largura e 24 na altura. Os tamanhos anteriores tornam-se ideais, limitados por esse espaço.
- Lista/detalhe em colunas quando há espaço; empilhados abaixo do breakpoint de cada seção. O divisor continua ajustável no modo amplo.
- Conteúdo longo rola; comandos de concluir, salvar e cancelar ficam fora da área de rolagem. Teclado visual usa rolagem horizontal para preservar teclas legíveis.
- AnyLayout reorganiza os mesmos filhos e owners. Não há troca de rascunho, salvamento automático nem redução por escala ao redimensionar.
- Painéis independentes de conteúdo e revisão respeitam a área útil da tela e podem ser redimensionados. O AppKit permanece nos presenters.
- Laboratório usa safeAreaInset para reservar a altura real dos controles, substituindo o deslocamento fixo de 92 pontos.

## Verificação automatizada

A primeira execução completa de `TICO_UI_TEST_DERIVED_DATA_PATH=/private/tmp/TicoResponsiveValidation-20261021 TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package` passou:

- SwiftPM build: PASS.
- App Target Xcode Debug e archive universal arm64 + x86_64: PASS.
- XCUITest existente de criar atalho desativado e persistir após reabrir: PASS.
- Suite Swift: 128 testes, 0 falhas.
- Subconjunto de segurança: 8 testes, 0 falhas.
- ZIP, DMG, assinatura local ad hoc e preflight: PASS.
- `git diff --check`: PASS.

Depois da inspeção visual, acrescentei rolagem automática para a configuração em edição ao atravessar o breakpoint do criador para o modo compacto. Build desse ajuste: PASS (3,21 s). A segunda execução passou pelos builds, mas falhou na navegação do XCUITest: a janela restaurou o tamanho compacto e o campo de nome estava abaixo da área visível. O teste existente foi ajustado para rolar até nome e ativação antes de interagir, com limite de tentativas e assertion de visibilidade. Nenhum caso de teste foi criado e nenhuma assertion anterior foi removida ou reduzida. A reexecução isolada do XCUITest passou em 53,65 s no tamanho compacto. A última execução do gate completo terminou com exit 0: builds SwiftPM/Xcode, archive universal, XCUITest (53,63 s), 128 testes Swift, 8 regressões de segurança, ZIP/DMG, assinatura ad hoc e preflight aprovados. O app final foi reaberto pelo caminho completo de dist/Tico.app.

## Verificação visual

Inspeção real por UI nativa na tela integrada, sem executar automações ou salvar novos registros:

| Cenário | Evidência |
|---|---|
| Biblioteca ampla → meia tela → quarto de tela | Colunas passam a lista acima do detalhe. Seleção preservada, detalhe rolável e editar/testar acessíveis. |
| Janela compacta | Aproximadamente 724 × 533 pontos de janela, correspondendo a 480 pontos de altura de conteúdo. Dimensões inferidas da captura Retina 1448 × 1066. |
| Criador compacto | Sheet capturada em aproximadamente 692 × 457 pontos (conteúdo limitado a 456); catálogo, URL, teclado, revisão e opções avançadas alcançáveis pela rolagem. Cancelar/voltar/continuar/criar permanecem visíveis. |
| Criador amplo | Sheet 980 × 740 pontos, catálogo e configuração em colunas. |
| Rascunho durante mudança de tamanho | URL sintética e foco preservados ao ampliar e reduzir. Após o ajuste final, a passagem de amplo para compacto também trouxe automaticamente a configuração à área visível; confirmado no app recompilado e na captura final, sem rolagem manual. |
| Cenas | Sheet capturada em aproximadamente 692 × 457; nome sintético, opções expandidas, rolagem e cancelar/salvar acessíveis. Rascunho descartado. |
| Mapa de gestos | Lista/detalhe empilhados, detalhe rolável, seleção preservada e prática acessível. |
| Prática | Sheet capturada em aproximadamente 560 × 457, conteúdo rolável e Encerrar prática fixo. Encerrada sem acionar automações. |
| Modelos e gestos | Estados vazios legíveis, navegação e busca acessíveis. |
| Permissões | Cards refluem em coluna; conteúdo rolável. Autorizações não alteradas. |
| Laboratório | Barra reorganizada em duas linhas; área abaixo reservada dinamicamente, diagnóstico alcançável. Captura física bloqueada pelas permissões atuais. |
| Conteúdo | Painel original 560 × 640 e redimensionado pelo macOS para aproximadamente 723 × 450. Texto sintético preservado, conteúdo rolável e Fechar/Nova receita fixos. |
| Receita | Escolhas em grade adaptável; cabeçalho e cancelar/salvar fora da rolagem. Cancelada sem persistir receita e painel fechado. |

Capturas locais: [criador amplo](criador-amplo.png), [criador compacto](criador-compacto.png), [cena compacta](cena-compacta.png), [prática](pratica-compacta.png), [laboratório](laboratorio-compacto.png), [receita em altura reduzida](receita-altura-reduzida.png).

A biblioteca continua com 5 regras, 3 ativadas. Nenhuma cena ou receita foi criada na inspeção; a entrada sintética foi encerrada junto com o painel.

## Limites

Esta rodada usa a tela integrada do Mac. O limite absoluto de 680 pontos da janela e 360 × 320 do painel está configurado no código, mas não foi alcançado por arrasto na inspeção automatizada; as dimensões verificadas estão na tabela acima. Rotinas e a revisão independente de layout foram revisadas em código e build, sem execução real nesta rodada. Visão geral, métricas e históricos pessoais não foram inspecionados na UI.

Na nova compilação local, Acessibilidade apareceu pendente e Monitoramento de Entrada negado. A captura ficou pausada. A renovação das permissões pelo usuário é necessária antes de testar captura global; isso não foi feito automaticamente.

Múltiplos monitores físicos, mudança de resolução do sistema, VoiceOver e tamanho de texto ampliado não foram validados. Builds e testes não comprovam TCC, gestos físicos, assinatura Developer ID ou notarização. Não há publicação nesta tarefa.

## Paralelo com React

AnyLayout muda a disposição dos filhos como uma alteração de flex-direction sem desmontar os componentes. O ambiente fornece os limites do container às sheets. O estado continua em @State/StateObject/ObservedObject existentes; não foi introduzida arquitetura React em SwiftUI.

## Estado de entrega

Tico atualizado aberto em Meus atalhos, no tamanho compacto, com 5 regras e 3 ativadas. Captura pausada. Rascunhos de verificação descartados. Sem commit, push, publicação ou novas dependências.
