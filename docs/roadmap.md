# Roadmap do Tico

## O que já está pronto

- Captura global de teclado, mouse e trackpad com fallback público.
- Motor de sessões, replay, calibração e diagnóstico de gestos.
- Tap, hold, TipTap, swipes, pinça, rotação, acordes e sequências.
- Gestos personalizados treinados localmente.
- Regras por aplicativo, perfis, prioridades e análise de conflitos.
- Workflows, automações locais, ações de aplicativos e janelas.
- Métricas locais, importação segura e persistência versionada.
- Identidade Tico aplicada ao produto, executável, dados e permissões técnicas.
- App Target Xcode fino, com Run/Profile/Archive e código compartilhado pelo
  package local.
- Gate de build, testes e segurança, com Developer ID local e empacotamento
  ad hoc exclusivo do CI.
- Documentação para publicação como preview técnico open source.
- Release 0.1.0 (build 2) disponível em DMG assinado e notarizado, conforme o
  [guia de distribuição](distribuicao.md).

## Atualizações concluídas

1. **Licença MIT:** adicionada em [`LICENSE`](../LICENSE). O código pode ser
   reutilizado nos termos dessa licença.
2. **Validação interna:** concluída manualmente no trackpad interno. Não há
   gate separado de relatório: build, testes, regressões de segurança, replay
   e pacote ad hoc são verificados automaticamente pelo CI. O relatório
   sanitizado permanece opcional para diagnosticar regressões físicas.
3. **CI remoto do macOS 26:** a execução
   [#31729757980](https://github.com/pedronazarito98/Tico/actions/runs/31729757980)
   concluiu com sucesso no runner `macos-26`. O App Target Xcode foi validado
   remotamente no run
   [#31741121816](https://github.com/pedronazarito98/Tico/actions/runs/31741121816),
   incluindo Debug, Archive Release, suíte, ZIP e DMG.

## O que fica para depois

1. **Validar hardware externo:** Magic Trackpad permanece sem garantia até
   existir um dispositivo para executar a matriz.
2. **Validar a instalação em outro Mac:** confirmar a abertura e os fluxos
   essenciais do mesmo artefato publicado em ambiente limpo.

## Backlog não bloqueante

Estes itens apareceram em planos antigos, mas não fazem parte do produto atual:

- desfazer parcialmente um workflow após falha;
- controlar volume e brilho com ações contínuas;
- oferecer uma grade de janelas totalmente configurável;
- exportar seletivamente pacotes de presets;
- criar um assistente após atualizações do macOS;
- investigar supressão segura de eventos de teclado e mouse.

A supressão de gestos do trackpad não é prometida: a captura atual é
observacional.

## Critério de evolução

O código e o DMG são distribuídos como **preview técnico open source**. Cada
novo artefato exige seus próprios gates de Developer ID, notarização e
Gatekeeper; a assinatura e o ticket de uma release anterior não validam uma
nova build. O teste em outro Mac continua pendente e limita a declaração de
prontidão para uso geral.
