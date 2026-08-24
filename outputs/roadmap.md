# Roadmap do Tico

## Estado do produto

O Tico está em **preview técnico open source para macOS 26+**. A implementação
principal, a arquitetura compartilhada entre SwiftPM e Xcode e o gate de QA
local permitem desenvolvimento e preparação de uma beta interna controlada.

Developer ID não faz parte do critério atual. Ele permanece necessário apenas
para uma futura distribuição binária pública, junto de notarização, staple,
Gatekeeper e máquina limpa.

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
- Shell Liquid Glass exclusivo do macOS 26.
- Gate local de build, testes, segurança e empacotamento ad hoc.
- XCUITest isolado para criação e persistência de regra.
- XCUITest de concessão e revogação simuladas sem modificar o TCC real.
- Reconciliação de permissões ao abrir, retomar ou atualizar a interface.
- Captura encerrada quando uma autorização antes válida é revogada.
- Toolbar e barra de menus conscientes de permissões.
- Validação automática da contagem da matriz manual.
- Documentação para publicação como preview técnico open source.

## Critério para beta interna

A beta interna pode avançar quando:

1. o HEAD pretendido passa no workflow `macOS verification`;
2. ZIP e DMG ad hoc passam no preflight estrutural;
3. a sessão manual usa um único artefato identificado por hash;
4. não existe `FAIL` em TCC, captura avançada, sleep/wake ou persistência;
5. qualquer cenário físico não executado continua explicitamente `NOT-RUN`.

Developer ID não é requisito desse critério.

## Próxima rodada manual

A próxima evidência necessária é operacional, não uma nova família de features:

1. executar a matriz com trackpad interno sobre um único `Tico.app`;
2. validar revogação e retorno de permissões no TCC real;
3. executar tap, hold, swipes, pinça e rotação;
4. validar fallback e restauração da captura avançada;
5. validar sleep/wake;
6. usar o Mac normalmente por pelo menos 15 minutos e contar falsos positivos;
7. validar persistência entre relançamento e atualização do artefato.

## O que fica para depois

1. **Validar hardware externo:** Magic Trackpad permanece sem garantia até
   existir um dispositivo para executar a matriz.
2. **Distribuir binário publicamente:** somente quando fizer sentido obter
   Developer ID, assinar, notarizar, validar o ticket, passar pelo Gatekeeper e
   testar o mesmo artefato em um Mac ou usuário limpo.

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

O código pode continuar público como **preview técnico open source**. Build e
pacote local não autorizam declarar compatibilidade física, estabilidade diária
ou distribuição pública. Cada afirmação deve apontar para o gate automatizado ou
para uma linha realmente executada da matriz manual.
