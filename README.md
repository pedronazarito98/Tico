<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="Design/Brand/Tico/Masters/tico-wordmark-dark.png">
    <img src="Design/Brand/Tico/Masters/tico-wordmark-light.png" width="452" alt="Tico">
  </picture>
</p>

<p align="center"><strong>Automatize sem interromper seu fluxo.</strong></p>

## Por que eu criei o Tico

Eu sentia falta de criar gestos do meu jeito. O macOS oferece bons atalhos,
mas eu queria transformar movimentos naturais do trackpad em ações realmente
úteis para o meu fluxo — abrir algo, organizar janelas ou executar uma
sequência sem precisar parar o que eu estava fazendo.

Comecei experimentando formas de capturar e reconhecer esses gestos localmente.
Essa solução para uma necessidade minha cresceu e virou o Tico: um pequeno
companheiro para conectar trackpad, teclado e mouse a automações no macOS.

## O que ele faz

- Cria regras com gestos, teclado e mouse.
- Reconhece taps, hold, swipes, pinça, rotação, TipTap e sequências.
- Abre apps e links, organiza janelas e executa workflows locais.
- Permite regras diferentes por aplicativo, condições e prioridades.
- Mostra conflitos antes de salvar duas regras que competem entre si.
- Oferece um Laboratório para visualizar, calibrar e testar gestos.

Tudo fica no Mac: regras, calibrações e histórico são locais.

## V2 em desenvolvimento

- **Painel contextual:** quatro ações perto do cursor, acessíveis pelo menu
  Atalhos → Painel de ações ou `⌃⌥⌘Espaço`. O atalho global exige captura ativa.
- **Mapa e prática:** consulte seus atalhos e pratique três reconhecimentos sem
  executar as ações. Com a captura ativa, segure `⌘⌥` para consultar a cola temporária.
- **Explorar:** ideias locais por objetivo, busca contextual e cartões compactos.
  Personalizar abre o criador; cancelar não deixa uma regra provisória.
- **Fazer com conteúdo:** texto, link ou arquivos fornecidos no painel, além de
  seleção explícita por Acessibilidade. As ações pesquisam em um destino HTTPS
  configurado ou enviam a entrada a um Atalho do macOS. Google e documentação Apple
  já aparecem como opções; novas receitas são configuradas no próprio painel,
  preservando a entrada e sem exigir um gatilho.
- **Aprender durante o uso:** um objetivo opcional no Mapa, progresso por execução
  real e dicas espaçadas depois de usar o painel contextual. Silenciar dicas não
  para a contagem; reiniciar um objetivo preserva o aprendizado dos outros atalhos.
- **Cenas:** sequências nomeadas com layout opcional, captura explícita, edição
  visual por janela, revisão Agora/Depois e restauração das janelas exatas da sessão.
  A revisão tem até cinco minutos independentes do tempo dos efeitos. Se expirar,
  retomar reconsulta as janelas sem repetir apps, links ou scripts já executados.
- **Rotinas de telas:** sugestões ao conectar, desconectar ou reorganizar telas;
  execução automática é opt-in e restrita a configurações com destino estável.
  Salvar pausada e ativar são escolhas explícitas; o modo exibido considera a
  configuração global, o runtime e a elegibilidade atual da cena.
- **Atividade:** estado atual com o próximo passo, uso por período, automações mais
  usadas e resultados filtráveis. Reconhecimento e execução da sessão ficam em
  detalhes separados; duração e confiança pertencem a cada registro. A exportação
  CSV acompanha os filtros e limpar o histórico exige confirmação.
- **Navegação:** Meus atalhos, Explorar, Cenas, Mapa e Atividade em destaque; ferramentas
  avançadas preservadas e pausa de captura por 15 minutos no menu de status.
- **Descrever automação:** monte uma frase com escolhas ou use o parser local.
  A proposta abre um rascunho no mesmo criador, inicialmente desativado.
  Exemplo: “Quando eu fizer um swipe para a esquerda com
  3 dedos no Safari, coloque a janela na metade esquerda”.

O parser usa uma gramática restrita, sem serviço de IA externo. A captura do layout
é explícita e não lê títulos nem documentos. A recuperação cobre posição e tamanho
na sessão atual; não reabre documentos ou aplicativos encerrados.
Veja o [guia das experiências contextuais](outputs/experiencias-contextuais.md),
a [validação desta integração](.specs/features/contextual-experiences/validation.md)
e a [evidência histórica da V2](.specs/features/tico-v2/validation.md).

Meus atalhos usa uma **lista com resumo compacto e detalhes expansíveis**. O criador
configura o resultado no próprio passo, separa **Gravar** de **Escolher** o
acionamento e permite conferir antes de salvar. **Testar acionamento** verifica
reconhecimento; não executa ações nem confirma o resultado de efeitos reais.
Cancelar a criação não persiste uma regra provisória.
Apps e Mais ajustes são opcionais; horário, monitor, título da janela e modificadores
ficam em Avançado. Rascunhos de edição permanecem na janela, e salvar é explícito,
também por `⌘S`. O editor completo continua no menu contextual da biblioteca.
Veja a [implementação e validação das dez telas aprovadas](.specs/features/tico-v2/figma-approved-flow.md).

As receitas manuais de conteúdo são configuração local em `content-recipes.json`,
separada do documento de regras. A entrada pessoal permanece somente na sessão,
expira após cinco minutos sem uso e é removida ao fechar, limpar, cancelar uma
execução ou concluir com sucesso. O import/export atual de regras não inclui
essas receitas. Consulte o [roteiro da revisão de UX](outputs/ux-continuity/guia.md)
e a [validação desta fase](.specs/features/ux-continuity/validation.md).

A escolha de ações usa uma galeria de resultados: aplicativos com ícones reais,
posições de janela ilustradas e operações diretas. Busca e seleção de apps ficam
no próprio inspetor. Veja a [validação dos seletores visuais](.specs/features/tico-v2/visual-selection.md).

## Estado atual

O Tico é um **preview técnico open source exclusivo para macOS 26+**. A forma
recomendada de testar por enquanto é clonar o repositório e rodar o app
localmente. Não há binário público assinado com Developer ID.

Para compilar localmente, use macOS 26 e Xcode 26 ou uma versão posterior
compatível. O aplicativo não oferece suporte a macOS 14–25.

Há validações manuais anteriores no trackpad interno, mas elas não substituem
uma nova rodada após mudanças de sistema ou de captura. Build, testes,
regressões de segurança, replay e pacote local são verificados
automaticamente; trackpad físico, TCC e recursos de acessibilidade permanecem
registrados separadamente na matriz manual.

Magic Trackpad e outros dispositivos externos ainda não têm compatibilidade
garantida. Quando houver um, o procedimento curto está no
[checklist de QA](outputs/qa-checklist.md#hardware-externo).

Os gestos globais avançados usam uma integração experimental com o macOS. Se
ela não estiver disponível, o Tico usa um fallback público com menos recursos.

## Como testar

Para desenvolver pelo Xcode, abra `Tico.xcodeproj`, selecione o scheme
compartilhado `Tico` e use Run. O target `TicoApp` é somente o host nativo do
`.app`: toda a aplicação continua em `Sources/Tico` e é consumida pelo package
local, sem cópia de telas, serviços ou recursos.

Para desenvolver e empacotar pelo fluxo SwiftPM existente, rode:

```sh
./script/build_and_run.sh
```

Para executar o gate completo:

```sh
./script/ci_verify.sh --package
```

Esse gate compila os hosts SwiftPM e Xcode, executa a suíte e valida os
artefatos ad hoc. O target Xcode também pode ser verificado isoladamente com
`./script/verify_xcode_app.sh`.

Na primeira execução, o macOS pode pedir Monitoramento de Entrada e, dependendo
da automação, Acessibilidade.

O projeto também gera `dist/Tico.zip` e `dist/Tico.dmg`. O DMG oferece o fluxo
convencional de arrastar o Tico para Aplicativos, mas usa a mesma assinatura do
app: ad hoc quando não há Developer ID instalado. ZIP e DMG servem para preview
técnico, desenvolvimento e QA local; não são releases públicas notarizadas.
Por segurança, a identidade ad hoc é específica de cada build e o macOS pode
pedir novamente permissões de privacidade após uma recompilação. Quem precisar
de continuidade local deve configurar explicitamente uma identidade de assinatura
própria; não existe requisito ad hoc compartilhado apenas pelo bundle identifier.

A versão do pacote fica em `version.env`. Antes de preparar uma nova versão,
atualize `MARKETING_VERSION` e incremente `BUILD_NUMBER`.

## Documentação

- [O que está pronto e o que falta](outputs/roadmap.md)
- [Como o projeto funciona](outputs/arquitetura.md)
- [Capacidades e limites do trackpad](outputs/trackpad.md)
- [Checklist de QA](outputs/qa-checklist.md)
- [Auditoria de compatibilidade com macOS 26](outputs/macos-26-compatibility-audit.md)
- [Matriz manual para macOS 26, trackpad e TCC](outputs/macos-26-manual-matrix.md)
- [Segurança](outputs/seguranca.md)
- [Distribuição](outputs/distribuicao.md)

## Licença

Este projeto é disponibilizado sob a [licença MIT](LICENSE).
