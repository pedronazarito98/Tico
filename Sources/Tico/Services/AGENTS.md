# Regras para Services

Além das regras superiores:

- Um service encapsula uma capacidade de domínio ou plataforma; não acumule estado de tela ou composição visual.
- Crie protocolo na fronteira usada pelo consumidor, com métodos e resultados tipados. Não replique toda a implementação no protocolo.
- Explicite ownership de callback, cancelamento, fila e ciclo de vida. Operações repetidas devem ser idempotentes quando o domínio exigir.
- Código que publica estado para UI usa `@MainActor`; trabalho fora da main thread deve retornar por uma fronteira definida.
- Todo `@unchecked Sendable` precisa de comentário de invariante, auditoria de mutabilidade e validação proporcional.
- Adapte AppKit, processos, eventos globais e bridge C em tipos estreitos. Não espalhe detalhes dessas APIs pelo domínio.
- Não registre payloads pessoais, gestos brutos, paths sensíveis, identificadores de dispositivo, tokens ou credenciais.
- Erros devem preservar causa útil de forma sanitizada; não use `print` como telemetria permanente.
- Replay, laboratório e validação nunca executam ações reais sem uma decisão explícita do fluxo.
