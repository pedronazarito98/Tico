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
- Permite regras diferentes por aplicativo, perfis e prioridades.
- Mostra conflitos antes de salvar duas regras que competem entre si.
- Oferece um Laboratório para visualizar, calibrar e testar gestos.

Tudo fica no Mac: regras, calibrações e histórico são locais.

## Estado atual

O Tico é um **preview técnico open source exclusivo para macOS 26+**. O código,
o App Target Xcode, o pacote SwiftPM e o fluxo de QA local estão preparados para
desenvolvimento e beta interna controlada.

A prontidão avaliada neste estágio não depende de Developer ID. É possível
compilar, executar e validar o Tico localmente com assinatura ad hoc. Developer
ID, notarização, staple, Gatekeeper e máquina limpa continuam sendo requisitos
somente para uma futura distribuição binária pública.

Para compilar localmente, use macOS 26 e Xcode 26 ou uma versão posterior
compatível. O aplicativo não oferece suporte a macOS 14–25.

### O que o gate automatizado comprova

- build dos hosts SwiftPM e Xcode;
- Archive Release universal e deployment target `26.0`;
- testes Swift e regressões de segurança;
- fluxo XCUITest isolado para criar e persistir uma regra;
- navegação para permissões e concessão/revogação simuladas sem tocar no TCC;
- consistência entre os cenários e o resumo da matriz manual;
- ZIP e DMG ad hoc, incluindo assinatura estrita e preflight estrutural.

### O que continua manual

Build, replay e XCUITest não comprovam contato físico no trackpad, TCC real,
sleep/wake, VoiceOver, falsos positivos em uso cotidiano nem reconexão de
hardware externo. Esses itens permanecem separados na
[matriz manual](outputs/macos-26-manual-matrix.md) e só mudam de `NOT-RUN`
quando o mesmo artefato é exercitado em uma sessão humana.

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
TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package
```

Esse gate compila os hosts SwiftPM e Xcode, executa a suíte, roda o XCUITest
isolado, confere a matriz manual e valida os artefatos ad hoc. O target Xcode
também pode ser verificado isoladamente com
`./script/verify_xcode_app.sh`.

Na primeira execução real, o macOS pode pedir Monitoramento de Entrada e,
dependendo da automação, Acessibilidade. O modo XCUITest não solicita essas
permissões e não inicia regras reais.

Para uma rodada física reproduzível, gere o pacote uma única vez, registre o
hash do ZIP e use o mesmo `Tico.app` durante toda a
[sessão manual](outputs/qa-checklist.md#sessão-manual-com-um-único-artefato).
Não recompile entre os cenários de TCC e trackpad.

O projeto também gera `dist/Tico.zip` e `dist/Tico.dmg`. O DMG oferece o fluxo
convencional de arrastar o Tico para Aplicativos, mas usa a mesma assinatura do
app: ad hoc quando não há Developer ID instalado. ZIP e DMG servem para preview
técnico, desenvolvimento e QA local; não são releases públicas notarizadas.

Por segurança, a identidade ad hoc é específica de cada build e o macOS pode
pedir novamente permissões de privacidade após uma recompilação. Quem precisar
de continuidade local deve configurar explicitamente uma identidade de
assinatura própria; não existe requisito ad hoc compartilhado apenas pelo
bundle identifier.

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
