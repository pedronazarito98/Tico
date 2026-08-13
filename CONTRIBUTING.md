# Como contribuir com o Tico

O Tico ainda é um preview técnico. Contribuições são bem-vindas sob os termos
da [licença MIT](LICENSE).

## Antes de abrir um pull request

1. Mantenha a mudança focada e preserve a arquitetura SwiftPM existente.
2. Execute:

   ```sh
   ./script/ci_verify.sh --package
   ```

3. Adicione ou atualize testes quando o comportamento mudar.
4. Não enfraqueça nem remova uma asserção somente para fazer a suíte passar.
5. Explique o que mudou, o impacto e como verificar.

Para mudanças arquiteturais, preserve a modernização incremental: crie a
fronteira, adapte a fachada compatível, migre consumidores e só remova código
quando ele estiver comprovadamente morto. Views devem receber valores,
bindings e ações estreitas; persistência deve permanecer atrás de codec e
repository; coordenadores devem declarar ownership e isolamento. Comandos de
menu usam `AppCommandRouter`, e operações que exigem AppKit ficam nos
adaptadores de ciclo de vida ou serviços de plataforma.

O target SwiftPM é `Tico`, com o bridge C
`TicoMultitouchBridge`. Não extraia `TicoCore` nem adicione
dependências sem uma análise de grafo e um gate próprios.

O gate automatizado cobre compilação, testes, regressões de segurança,
replay e empacotamento ad hoc em ZIP e DMG. Ele não comprova hardware físico,
compatibilidade com todas as versões do macOS, Developer ID ou notarização.
Os metadados do bundle vêm de `version.env`; mudanças de release devem atualizar
`MARKETING_VERSION` e sempre incrementar `BUILD_NUMBER`.

Para uma mudança que altere o comportamento do trackpad, execute também o
trecho aplicável do [checklist manual](outputs/qa-checklist.md). O relatório
sanitizado de hardware é opcional e útil apenas para investigar uma regressão
ou registrar uma combinação específica de macOS e dispositivo.

## Segurança

Não divulgue uma possível vulnerabilidade em issue ou pull request público.
Siga [SECURITY.md](SECURITY.md) e remova credenciais, caminhos pessoais,
identificadores de dispositivos, dados do TCC e gravações brutas.
