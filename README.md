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

O Tico é um **preview técnico open source para macOS 14+**. A forma
recomendada de testar por enquanto é clonar o repositório e rodar o app
localmente. Não há binário público assinado com Developer ID.

O uso no trackpad interno do Mac já foi validado manualmente. Build, testes,
regressões de segurança, replay e pacote local são verificados
automaticamente pelo CI; não existe um gate separado que exija formalizar a
validação manual em relatório.

Magic Trackpad e outros dispositivos externos ainda não têm compatibilidade
garantida. Quando houver um, o procedimento curto está no
[checklist de QA](outputs/qa-checklist.md#hardware-externo).

Os gestos globais avançados usam uma integração experimental com o macOS. Se
ela não estiver disponível, o Tico usa um fallback público com menos recursos.

## Como testar

Clone o projeto e rode:

```sh
./script/build_and_run.sh
```

Para executar o gate completo:

```sh
./script/ci_verify.sh --package
```

Na primeira execução, o macOS pode pedir Monitoramento de Entrada e, dependendo
da automação, Acessibilidade.

O projeto também gera `dist/Tico.zip` e `dist/Tico.dmg`. O DMG oferece o fluxo
convencional de arrastar o Tico para Aplicativos, mas usa a mesma assinatura do
app: ad hoc quando não há Developer ID instalado. ZIP e DMG servem para preview
técnico, desenvolvimento e QA local; não são releases públicas notarizadas.

## Documentação

- [O que está pronto e o que falta](outputs/roadmap.md)
- [Como o projeto funciona](outputs/arquitetura.md)
- [Capacidades e limites do trackpad](outputs/trackpad.md)
- [Checklist de QA](outputs/qa-checklist.md)
- [Segurança](outputs/seguranca.md)
- [Distribuição](outputs/distribuicao.md)

## Licença

Este projeto é disponibilizado sob a [licença MIT](LICENSE).
