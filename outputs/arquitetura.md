# Arquitetura do Tico

O Tico é um aplicativo nativo exclusivo para macOS 26+, feito em SwiftUI e organizado
como um pacote SwiftPM consumido por dois hosts finos. Produto, executável,
bundle e módulo compartilhado usam a identidade `Tico`.

## Hosts de desenvolvimento

- **SwiftPM:** o produto executável `Tico` usa `TicoLauncher` como `@main`.
- **Xcode:** o target `TicoApp`, no scheme compartilhado `Tico`, gera
  `Tico.app` e usa `TicoXcodeApp` como `@main`.
- **Aplicação compartilhada:** o produto de biblioteca `TicoApplication`
  expõe o módulo `Tico`, onde vivem `TicoApp`, views, stores, serviços e
  recursos.

Os launchers apenas chamam `TicoApp.main()`. O projeto Xcode referencia o
package local e reutiliza o mesmo ícone e bundle de resources; não existe uma
segunda cópia da aplicação. O nome técnico `TicoApp` evita colisão de produtos
de build com o módulo SwiftPM `Tico`, mas não altera a identidade pública.

## Camadas

- **Modelos:** regras, gatilhos, gestos, perfis, workflows e ações.
- **Armazenamentos:** persistência versionada, calibração, métricas e logs.
- **Serviços:** permissões, captura, reconhecimento, contexto e execução.
- **Bridge do trackpad:** fronteira C pequena que carrega
  `MultitouchSupport` dinamicamente.
- **Interface:** telas SwiftUI, Laboratório e item da barra de menus.

## Fluxo de uma entrada

1. O app verifica Monitoramento de Entrada e Acessibilidade quando necessário.
2. Teclado e mouse são normalizados em `InputEventDescriptor`.
3. O trackpad usa captura privada ou fallback público.
4. Frames viram sessões, características e candidatos de gesto fora da thread
   principal.
5. O motor escolhe o gesto e avalia contexto, sequência, prioridade e
   conflitos.
6. A ação só é executada depois que uma regra compatível é encontrada.

Replay usa o mesmo motor de reconhecimento, mas fica isolado do executor de
ações. Ele pode atualizar o Laboratório e os diagnósticos sem disparar regras.

## Identidade e persistência

- Bundle público: `Tico.app`.
- Artefatos: `Tico.zip` e `Tico.dmg`.
- Executável: `Tico`.
- Bundle identifier: `com.pedronazarito.Tico`.
- Dados: `Application Support/Tico`.
- Preferências: chaves `com.tico.*`.

Esses nomes técnicos não devem ser alterados sem uma migração própria, com
cópia atômica, validação e rollback.

### Ação de atualização e migração dos dados

A ação `refreshWindow` solicita o comando acessível de atualização do aplicativo
e da janela em foco. A consulta é limitada a menus conhecidos e à barra de
ferramentas, sem registrar seus títulos; não há envio de teclas nem garantia de
que todos os aplicativos ofereçam um comando compatível. A execução revalida o
foco antes do efeito e informa falha ou resultado incerto quando necessário.

O documento de regras passou da versão 8 para a 9 para representar a nova ação.
Na primeira leitura, o repositório preserva uma cópia do documento anterior e
grava o novo formato atomicamente. Se já existir uma cópia da mesma versão,
outra é criada com sufixo numérico. Regras anteriores que enviam `⌘R` continuam
inalteradas, pois a mesma combinação pode ter outra intenção.

O documento de registros de execução passou da versão 1 para a 2. A versão nova
lê os registros anteriores e escreve o formato atualizado na próxima execução.
Versões anteriores do Tico não entendem os novos dados: não as inicie com o
mesmo diretório após a migração, pois uma falha de leitura seguida de gravação
pode sobrescrever dados. O backup das regras representa o estado anterior à
migração, não as alterações feitas depois dela.

## Estrutura efetivamente entregue na modernização

A modernização foi aplicada por fronteiras internas, mantendo um único target
SwiftPM de implementação e as fachadas existentes:

- **Editor:** `RuleEditingSession` é a fonte de verdade do rascunho, dirty
  state, validação e transições; `RuleEditorView` compõe header, trigger,
  trackpad e footer por bindings e ações estreitas.
- **Persistência:** `ShortcutDocumentCodec` é dono do formato/migrações;
  `ShortcutRepository` é a porta de IO; `ShortcutStore` publica estado e
  invariantes sem concentrar encode/decode ou escrita atômica.
- **Aplicação:** `CaptureCoordinator`, `AutomationCoordinator` e
  `LaboratoryCoordinator` são owners `@MainActor` separados; `AppController`
  compõe dependências, encaminha eventos e conserva a fachada consumida pela
  UI.
- **Shell:** `AppCommandRouter` recebe comandos tipados e consome cada
  envelope uma vez. As notificações internas usam o namespace `Tico.*`.
  `ApplicationLifecycleService` concentra
  `NSApplication`/`NSWindow`; as views não importam nem referenciam AppKit.

O target `TicoCore` não foi criado. Os modelos usam `Foundation`, mas
formam uma malha interna compartilhada com stores, serviços, coordenadores e
views; a extração exigiria expor APIs internas ou levar dependências de
plataforma para o novo target. Essa decisão está detalhada em
`.specs/features/architecture-modernization/design.md`.

A adição posterior dos launchers não é uma extração de domínio: ela separa
somente a responsabilidade de iniciar o mesmo app em SwiftPM e Xcode.

## Limites de validação

Build, suíte, replay determinístico e pacote ad hoc comprovam compilação,
testes e isolamento lógico. Não comprovam interação contínua do shell nativo,
trackpad físico, TCC em máquina real, sleep/wake físico, assinatura Developer
ID ou notarização. Esses itens são gates separados e devem permanecer
`NOT-RUN` até existir evidência manual correspondente.
