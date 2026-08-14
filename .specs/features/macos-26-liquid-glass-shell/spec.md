# Shell Liquid Glass do macOS 26

**Status**: Implementado — aguardando verificação independente
**Plataforma**: macOS 26+

## Objetivo

Atualizar o shell principal, a Visão geral e o Laboratório do Tico para usar a
linguagem nativa do macOS 26 com Liquid Glass, mantendo o módulo SwiftPM, o App
Target fino, a navegação, a acessibilidade e os comportamentos existentes.

## Fora de escopo

- adicionar novas famílias de gestos;
- alterar persistência, regras ou execução de automações;
- declarar compatibilidade física sem uma sessão de hardware detalhada;
- preparar uma distribuição pública notarizada.

## Critérios de aceitação

### LG-01 — Shell e busca

Ao selecionar uma seção ou regra encontrada pela busca, inclusive o item já
selecionado, a busca deve ser encerrada, a sidebar completa deve reaparecer e o
destino correto deve permanecer selecionado.

### LG-02 — Controle de captura

A Visão geral deve apresentar um controle Liquid Glass com estados distintos
para permissão necessária, captura pausada, captura ativa e fallback limitado.
O controle deve respeitar Reduzir Movimento e encaminhar a ação primária sem
duplicar estado de domínio.

### LG-03 — Visão geral contínua

A Visão geral deve organizar identidade, ações, métricas e atividade em um
fluxo contínuo, reduzindo cards opacos sem perder contraste, hierarquia ou os
atalhos existentes.

### LG-04 — Laboratório imersivo

O Laboratório deve usar a superfície do trackpad como plano contínuo, com HUD
Liquid Glass para modo, estado de captura e sessão. Métricas e diagnóstico
devem permanecer legíveis sobre a superfície.

### LG-05 — Acessibilidade

Controles devem manter rótulos e valores coerentes. Ícones puramente
decorativos não devem produzir ações ou nomes falsos na árvore de
acessibilidade.

### LG-06 — Integração e plataforma

Os hosts SwiftPM e Xcode devem compilar com mínimo macOS 26. A suíte existente,
as regressões de segurança e os pacotes ZIP/DMG ad hoc devem continuar
aprovados. Hardware físico e notarização permanecem gates separados.

## Verificação

- gate canônico: `TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package`;
- UAT visual e de interação no `dist/Tico.app` final;
- matriz sanitizada em `outputs/macos-26-manual-matrix.md`;
- verificação independente registrada em `validation.md`.
