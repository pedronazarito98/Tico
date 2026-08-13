# Tico Release Readiness Context

**Gathered**: 2026-07-26
**Spec**: `.specs/features/release-readiness/spec.md`
**Status**: Design complete, with explicit defaults pending user approval

## Feature Boundary

Fechar o ciclo de publicação do Tico existente: gates automatizados,
documentação coerente, matriz física de trackpad, pré-flight de assinatura e
verificação independente. O ciclo não adiciona novos gestos, backend ou
compatibilidade com a Mac App Store.

## Implementation Decisions

### Estado público

- O repositório pode ser apresentado como technical preview/alpha após os gates automatizados.
- O status não será promovido a stable enquanto houver linhas físicas obrigatórias como `NOT-RUN` ou `FAIL`.

### Hardware e fallback

- O laboratório e o replay continuam sendo as fontes de diagnóstico.
- Replay nunca entra no executor de regras.
- A captura privada e o fallback público são registrados separadamente.
- A ausência de `MultitouchSupport` é uma limitação explícita, não um motivo para alegar PASS.

### Evidência pública

- Relatórios commitados usam classes de dispositivo e versões, não serial, nome de usuário, TCC dump ou frames brutos.
- O relatório deve permitir reproduzir a decisão, mas não precisa conter dados suficientes para reproduzir a sessão privada individual.

### Release

- `--package` continua sendo o caminho de dry-run/local ad hoc.
- O caminho Developer ID será uma etapa separada e só poderá afirmar notarização após evidência de `notarytool`, `stapler` e máquina limpa.

### Documentação

- `⌘6` é o atalho canônico porque é o comportamento atual em `Commands.swift` e no README.
- O checklist será corrigido para não manter a referência histórica a `⌘4`.

## Agent's Discretion

- Escolher o nome exato do workflow, desde que o comando local e o CI compartilhem o mesmo gate.
- Escolher Markdown ou JSON para o resumo sanitizado, desde que todas as colunas de RR-07 sejam preservadas.
- Escolher a licença somente após verificar que não há dependência/licença incompatível; se a escolha exigir decisão legal, deixar `LICENSE` como bloqueio explícito.

## Declined / Undiscussed Gray Areas → Assumptions

- Não foi feita uma sessão de discussão interativa antes deste plano; os defaults acima são as decisões operacionais escolhidas pelo agente e devem ser confirmados antes da execução.
- A existência de Magic Trackpad é tratada como “quando disponível”; ausência gera `NOT-RUN`, nunca PASS.
- A disponibilidade de conta Apple Developer não é presumida.

## Specific References

- `README.md`
- `SECURITY.md`
- `outputs/qa-checklist.md`
- `outputs/relatorio-correcoes-seguranca.pt-BR.md`
- `outputs/evidencias-validacao-seguranca.pt-BR.md`
- `outputs/signing-and-distribution.md`
- `Sources/Tico/Services/TrackpadGestureService.swift`
- `Sources/Tico/Services/MultitouchFrameProvider.swift`
- `Sources/Tico/App/Commands.swift`
- `script/build_and_run.sh`

## Deferred Ideas

- Novos reconhecedores e gestos.
- Enumeração completa de dispositivos privados além do suporte já existente.
- Telemetria remota ou coleta automática de relatórios.
- Distribuição pela Mac App Store.
