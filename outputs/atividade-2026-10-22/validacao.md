# Atividade, Cenas e remoção de Perfis

## Entrega

- **Atividade** substitui Visão geral e Métricas no menu lateral e no comando ⌘1. A restauração de navegação antiga aponta para a nova tela.
- **Agora** mostra o estado da captura, explica o que falta e oferece uma ação direta. A captura de teclado/mouse é diferenciada da disponibilidade do trackpad.
- **Seu uso** oferece Hoje, Últimos 7 dias, Últimos 30 dias e Todo o histórico. Contagens e automações mais usadas derivam do mesmo recorte e da busca.
- **Resultados** separa conclusão, falha, cancelamento e reconhecimento rejeitado; permite filtrar por automação e resultado, agrupa por dia e revela detalhes sob demanda. Os 50 primeiros itens aparecem inicialmente, com carregamento dos demais pelo botão Mostrar mais.
- A exportação CSV inclui todos os resultados filtrados, mesmo os ainda não exibidos. Limpar histórico exige confirmação e restaura o estado em memória se a gravação falhar.
- **Cenas** usa a largura real disponível, conteúdo centralizado com limite de 1.080 pontos e uma ou duas colunas de cartões conforme o espaço. A rolagem mantém as ações acessíveis em janelas baixas.
- **Perfis** foi removido da interface, menus, editores, estado e matching. Resta apenas a leitura de compatibilidade para documentos antigos.

## Decisões técnicas

SwiftUI, Swift Package Manager, macOS 26+ e os tokens existentes foram preservados. Não foram acrescentadas dependências, arquivos de teste, mocks ou fixtures. Testes existentes foram adaptados para os contratos alterados.

A tela observa MetricsStore diretamente. ActivitySummary faz apenas cálculos puros; filtros e expansão pertencem à janela. O estado atual não muda quando o período histórico é alterado. Confiança e duração ficam em cada execução, evitando um score geral ambíguo. O histórico mantém o formato de persistência existente e o limite de 1.000 eventos.

A remoção de Perfis usa migração para o documento v8. Condições, aplicativos e prioridades herdadas são incorporados aos atalhos/modelos. Atalhos associados ficam pausados para revisão; associações órfãs continuam bloqueadas por uma condição que não corresponde a aplicativos. O repository existente preserva o original antes de salvar a migração. Fluxos, modelos de gesto e cenas são mantidos.

**Paralelo com React:** ActivitySummary equivale a um selector derivado do store. @State guarda os filtros locais; @SceneStorage restaura o período por janela. GeometryReader fornece o espaço que o pai realmente oferece e AnyLayout reorganiza os mesmos elementos — semelhante a container queries, mas seguindo o sistema de proposta de tamanho do SwiftUI, sem CSS ou DOM.

## Validação manual sugerida

1. Abra **Atividade** ou pressione ⌘1. Confira a explicação e a ação oferecida em Agora.
2. Escolha outro período e use a busca. A situação atual da captura deve permanecer igual.
3. Com histórico disponível, clique em uma automação de Mais usados; filtre resultados, expanda uma linha e abra o atalho correspondente.
4. Exporte o recorte e compare as linhas do CSV com os resultados filtrados. O menu Limpar histórico informa que remove inclusive registros fora do filtro.
5. Redimensione a janela com a barra lateral aberta e fechada, incluindo o menor tamanho permitido (conteúdo mínimo de 680 × 480 pontos). Títulos e controles devem reorganizar-se, e conteúdo alto deve continuar rolável.
6. Confira **Cenas** vazia e com cartões. Abra/cancele a criação de cena e compare janela ampla e compacta.
7. Caso utilizasse Perfis, revise as condições dos atalhos migrados antes de reativá-los.

## Evidências

- `git diff --check`: PASS.
- Primeiro gate completo desta etapa: PASS, incluindo 128 testes Swift, 8 regressões de segurança, XCUITest isolado (criação desativada + reabertura + persistência), builds SwiftPM/Xcode, archive universal arm64/x86_64 e ZIP/DMG ad hoc.
- Revisão do pacote instalado encontrou uma exceção de AppKit ao reabrir janelas: a família de toolbar customizável `main-toolbar` duplicava o botão automático da sidebar. A toolbar foi convertida para composição por janela, mantendo controles, ações e identificadores acessíveis. O app empacotado foi reconstruído e abriu normalmente após a correção, inclusive com mais de uma janela.
- Gate completo após a correção da toolbar: **PASS** (`TICO_UI_TEST_DERIVED_DATA_PATH=/private/tmp/TicoResponsiveValidation-20261021 TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package`, saída 0). Confirmou novamente 128 testes Swift, 8 regressões de segurança, XCUITest, SwiftPM/Xcode, archive universal e pacote ZIP/DMG. Não houve alteração de código depois desse gate.
- Inspeção nativa interativa do pacote em dados isolados: Atividade e Cenas vazias, janela ampla e compacta, rolagem até o fim, mudança de período, navegação com ⌘1, ação Revisar permissões, abertura/cancelamento do criador de cena, modo escuro de Atividade e recolhimento da sidebar: PASS.
- A janela compacta observada foi de aproximadamente 724 × 533 pontos; a ampla ocupou a área disponível de aproximadamente 1.454 × 907 pontos. O app mantém o mínimo de conteúdo de 680 × 480 pontos.
- Os cálculos de atividade preenchida (períodos, agrupamento por identidade, busca, separação dos resultados e exportação filtrada) foram verificados nos testes existentes. A revisão visual desta etapa usou histórico vazio; listas preenchidas e múltiplos cartões de cenas ainda devem ser conferidos no uso manual.
- Nenhum histórico pessoal foi usado como fixture. Capturas mostram somente a instância isolada, com os dois exemplos desativados que o app já cria nesse modo.

### Capturas da versão empacotada

- [Atividade ampla](atividade-ampla.jpg)
- [Atividade compacta](atividade-compacta.jpg)
- [Atividade escura](atividade-escura.jpg)
- [Cenas compacta](cenas-compacta.jpg)
- [Cenas ampla](cenas-ampla.jpg)


## Limites

A validação automática usa dados e preferências isolados, sem executar automações reais. Não representa validação de trackpad físico, TCC, múltiplos monitores, VoiceOver, Reduce Motion, notarização ou máquina limpa. Artefatos locais usam assinatura ad hoc. Não foram realizados commit, push ou publicação.

## Verificação antes do commit e push — 25/10/2026

- `origin/main` atualizado por fetch; HEAD e origin/main estavam alinhados antes dos commits.
- `swift build --disable-sandbox --product Tico`: PASS, build incremental sem recompilação dos fontes (0,66 s).
- `swift test --disable-sandbox`: PASS, 128 testes e zero falhas (incluindo as regressões de segurança existentes).
- `git diff --check`: PASS.
- Código preservado desde o gate completo de 22/10. Nesta preparação, apenas referências de documentação foram ajustadas para caminhos portáveis; o README passou a listar Atividade na navegação.
- XCUITest, archive universal e empacotamento completo não foram repetidos nesta preparação; a evidência correspondente permanece datada em 22/10.
- `dist/`, dados pessoais e preferências locais permanecem fora do versionamento.
