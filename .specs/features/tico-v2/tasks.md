# Execução

Oito entregas sequenciais; sem commits e sem arquivos de teste por instrução do projeto.
Não marcar concluído somente por inspeção. Gate bloqueado não é PASS.

1. [x] Implementação de segurança de prática e explicações (V2-02/05): sessão + coordenador/controller. Build PASS e revisão; efeitos físicos NOT-RUN.
2. [x] Catálogo e revisão de receitas (V2-03): modelo + tela Explorar + editor existente. UAT de instalação desativada PASS.
3. [x] Rascunho por texto (V2-07): parser restrito + tela de revisão. UAT válido/inválido e salvamento desativado PASS.
4. [x] Implementação do mapa e prática guiada (V2-02): lista contextual + sheet. Listagem e recusa sem permissão PASS; três gestos físicos NOT-RUN.
5. [x] Implementação de cenas (V2-04): biblioteca + edição + execução/cancelamento. Criação e persistência UAT PASS; efeitos reais NOT-RUN.
6. [x] Painel contextual (V2-01): adaptador nativo + SwiftUI + comandos. Abertura, quatro ações e Escape UAT PASS; execução externa NOT-RUN.
7. [x] Shell e menu (V2-06/05): navegação, atalhos, pausa e explicações. Navegação via menu UAT PASS; pausa completa e diagnóstico físico NOT-RUN.
8. [ ] Fechamento integral: revisão independente e UAT isolado executados, porém suíte/gate BLOCKED e hardware NOT-RUN. Detalhes em validation.md.

Os itens 1–7 assinalam implementação entregue com build executado, não aceite
integral de todos os cenários. O item 8 permanece aberto até remover os bloqueios.

## Gates

- Menor gate: swift build --disable-sandbox --product Tico
- Regressão: swift test --disable-sandbox
- Fechamento: git diff --check e TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package
- Alternativa instalada: DEVELOPER_DIR=/Library/Developer/CommandLineTools para SwiftPM;
  Xcode depende da licença aceita pelo usuário, nunca pelo agente.

## Cobertura

Suíte existente cobre domínio/persistência/segurança. Novos critérios V2 dependem
de inspeção independente e UAT, sem alegação de cobertura automatizada nova.
