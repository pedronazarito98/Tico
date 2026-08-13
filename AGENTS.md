# AGENTS.md — Tico

Estas regras valem para todo o repositório. Um `AGENTS.md` mais próximo do arquivo pode especializá-las, mas não pode reduzir segurança, evidência ou limites de autorização.

## Antes de alterar

1. Leia `Package.swift`, `README.md`, `CONTRIBUTING.md` e os arquivos diretamente envolvidos.
2. Para trabalho arquitetural, leia `.specs/STATE.md` e `.specs/features/architecture-modernization/{spec,design,tasks}.md`.
3. Verifique `git status --short`; preserve mudanças do usuário e não misture escopo não relacionado.
4. Entenda o padrão existente antes de criar arquivos, tipos ou pastas.

## Contratos do projeto

- Preserve SwiftUI, Swift Package Manager e o deployment target macOS 26+; não introduza framework arquitetural ou dependência sem aprovação.
- `Tico` é o nome público e o módulo compartilhado. Preserve o produto e executável `Tico`, o módulo SwiftPM `Tico`, o App Target fino `TicoApp`, o bundle identifier, o diretório de dados e as preferências com a identidade Tico.
- Prefira refatoração incremental com fachada compatível. Não faça reescritas amplas.
- Não use arquivos agregadores apenas para reexportar símbolos. Importe módulos reais diretamente.
- Não mova ou renomeie código sem benefício de responsabilidade demonstrável.
- Preserve comportamento, acessibilidade, atalhos, light/dark mode e design tokens existentes.

## Arquitetura

- `App`: composition root, cenas e coordenação do shell; comandos entram pelo
  roteador tipado e o ciclo de vida AppKit fica no adaptador estreito.
- `Models`: tipos de domínio e lógica pura, sem IO ou UI.
- `Services`: domínio, plataforma e efeitos atrás de interfaces estreitas.
- `Stores`: estado observável e invariantes; persistência complexa deve ficar em codec/repositório.
- `Views`: composição visual, estado efêmero e envio de ações; sem regra de negócio complexa no `body` e sem referências diretas a AppKit.
- `Support`: fronteiras pequenas compartilhadas e tipos de coordenação com owner explícito; não é destino genérico para responsabilidades sem owner.
- Crie abstrações em fronteiras de efeitos ou quando já existirem consumidores reais. Evite containers e protocolos genéricos “para o futuro”.

## Swift e concorrência

- Use tipagem explícita quando ela esclarecer contratos; evite casts forçados e force unwrap sem invariante comprovada.
- Objetos de UI e estado publicado são `@MainActor` quando apropriado.
- Toda fila, callback C/AppKit, actor ou `@unchecked Sendable` deve ter ownership e invariantes documentados.
- Não migre em massa para `@Observable` ou Swift 6 estrito sem uma spec e um gate próprios.
- Integração AppKit deve ser estreita e ficar fora das views sempre que possível.

## Segurança e privacidade

- Não leia, copie, persista ou exponha credenciais, tokens, sessões, cookies, bancos SQLite de autenticação, logs brutos, paste cache ou históricos pessoais.
- Não inclua identificadores de dispositivo, TCC ou gravações pessoais em fixtures, documentação ou commits.
- Se um segredo aparecer acidentalmente, registre somente `[REDACTED]` e interrompa a exposição.
- Replay e testes nunca devem executar ações reais do usuário.

## Testes e evidência

- Não crie arquivos de teste, mocks ou fixtures sem pedido explícito do usuário ou autorização registrada na tarefa.
- Nunca remova, pule ou enfraqueça assertions para obter verde.
- Rode o menor gate relevante durante a tarefa e o gate completo ao fechar uma fase.
- Comandos canônicos:

```bash
git diff --check
swift build --disable-sandbox --product Tico
swift test --disable-sandbox
TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package
```

- Não declare teste, lint, build, hardware, assinatura ou notarização como aprovados sem execução real. Use `NOT-RUN` ou `BLOCKED` quando aplicável.
- Build e replay não provam trackpad físico, TCC, sleep/wake, assinatura ou notarização.

## Escopo e autorização

- Altere apenas arquivos necessários para a tarefa; justifique qualquer expansão.
- Não faça commit, push, PR, release, publicação ou mudança externa sem solicitação explícita.
- Nunca descarte mudanças do usuário ou use comandos destrutivos para “limpar” o worktree.
- Em execução com agentes, use worktrees isolados, ownership de arquivos e integração serial para seams compartilhados.

## Entrega

Responda em pt-BR com:

1. resumo do que foi alterado;
2. arquivos modificados/criados;
3. decisões técnicas;
4. pontos de atenção;
5. o que validar manualmente.

Separe fatos verificados de inferências e recomendações.
