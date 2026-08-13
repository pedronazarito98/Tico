# Auditoria de compatibilidade — macOS 26

Data da rodada: `2026-08-13`.

## Resultado

O código, o manifesto SwiftPM, o App Target Xcode e os artefatos locais estão
configurados para executar exclusivamente no macOS 26 ou posterior. A
auditoria automatizada e a auditoria visual local passaram sem falhas
conhecidas no escopo executado.

A compatibilidade física completa ainda não pode ser declarada: 22 cenários da
[matriz manual](macos-26-manual-matrix.md) permanecem `NOT-RUN` porque exigem
ação humana, mudança real de TCC, trackpad físico, sleep/wake, VoiceOver ou uma
atualização entre builds. Nenhum desses itens foi inferido a partir de testes.

## Ambiente verificado

- macOS `26.5.2` (`25F84`), Apple silicon;
- Xcode `26.6` (`17F113`);
- Swift `6.3.3`, target da toolchain `arm64-apple-macosx26.0`;
- Tico `0.1.0 (1)`.

## Deployment target

| Camada | Resultado | Evidência |
| --- | --- | --- |
| SwiftPM | `PASS` | plataforma `macos 26.0` no manifesto resolvido |
| Executável Tico | `PASS` | `LC_BUILD_VERSION minos 26.0` |
| Executável de testes | `PASS` | `LC_BUILD_VERSION minos 26.0` |
| App Target Xcode Debug | `PASS` | `Tico.app`, scheme `Tico`, `LSMinimumSystemVersion = 26.0` |
| Archive Xcode Release | `PASS` | universal `arm64` + `x86_64`, ambos com `minos 26.0` e Hardened Runtime |
| Bundle `.app` | `PASS` | `LSMinimumSystemVersion = 26.0` |
| Scripts de pacote e preflight | `PASS` | validam explicitamente `26.0` |
| CI da AD-011 | `PASS` remoto | run `31729757980` concluído no runner `macos-26` |
| CI da AD-012 | `NOT-RUN` remoto | branch local ainda não publicada; workflow já inclui o gate Xcode |

A linha `Target Platform: arm64e-apple-macos14.0` emitida pela biblioteca
Swift Testing não representa o deployment target do produto. A inspeção do
Mach-O do app e do bundle XCTest confirmou `minos 26.0`.

## Gate automatizado

Comando executado:

```sh
TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package
```

Resultados:

- `PASS`: build SwiftPM;
- `PASS`: App Target Xcode Debug e Archive Release universal;
- `PASS`: identidade, versão, categoria, ícone, resources, assinatura ad hoc
  estrita, Hardened Runtime e mínimo `26.0` no host Xcode;
- `PASS`: 125 testes, zero falhas;
- `PASS`: 8 regressões de segurança, zero falhas;
- `PASS`: ZIP e DMG ad hoc, assinatura profunda estrita e metadados;
- `PASS`: versão mínima `26.0` nos artefatos;
- `PASS` histórico da AD-011: GitHub Actions no macOS `26.5.2`, Xcode
  `26.6` e Swift `6.3.3`;
- `NOT-RUN` remoto para AD-012: a branch atual ainda não foi publicada;
- `NOT-RUN`: Developer ID, notarização, staple, Gatekeeper e máquina limpa.

## Runtime do host Xcode

O `.app` Debug do target Xcode foi copiado para uma área temporária, recebeu
bundle identifier exclusivo e executou com diretório home isolado. O processo
abriu uma janela real de camada 0, com título `Visão geral`, e foi encerrado e
removido depois da inspeção. Isso confirma que o launcher Xcode inicia o mesmo
`TicoApp` sem reutilizar os dados do Tico instalado.

A tentativa de screenshot dessa janela retornou `could not create image from
window`; portanto, screenshot do novo host fica `NOT-RUN`, sem ser inferido do
processo. A auditoria visual abaixo permanece válida para a árvore SwiftUI
compartilhada, que não foi copiada ou alterada pelos launchers.

## Auditoria visual

A inspeção foi feita no `.app` empacotado, em cópia temporária com identidade e
diretório de dados isolados. Foram inspecionados:

- janela principal nos tamanhos padrão e mínimo;
- aparências clara e escura;
- wordmark, sidebar, toolbar e cards da visão geral;
- Ajustes Geral e Segurança;
- menu da barra de menus;
- abas Ao vivo, Calibração, Sessões e Validação do Laboratório;
- estados sem Acessibilidade e sem Monitoramento de Entrada.

Dois defeitos foram encontrados e corrigidos durante a rodada:

1. o wordmark não era carregado no `.app` empacotado;
2. a calibração estourava horizontalmente no tamanho mínimo.

Após as correções, os fluxos reinspecionados não apresentaram corte,
sobreposição, perda de contraste ou controles inacessíveis no escopo visual
executado.

## Limites e próximos gates

Permanecem manuais e bloqueiam uma declaração de compatibilidade física total:

- Reduzir Transparência, Reduzir Movimento, Aumentar Contraste e VoiceOver;
- concessão, revogação e abertura dos painéis reais de TCC;
- gestos em trackpad interno e Magic Trackpad;
- fallback físico, pressão, uso contínuo e falsos positivos;
- sleep/wake e desconexão/reconexão;
- persistência e atualização entre duas builds reais;
- Developer ID, notarização e validação em ambiente limpo.
