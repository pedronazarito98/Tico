# Matriz manual — macOS 26, trackpad e TCC

Esta matriz valida o comportamento que build, testes e replay não conseguem
provar. Comece com todos os itens em `NOT-RUN` e altere somente o que foi
executado na mesma sessão para `PASS` ou `FAIL`.

## Regras de evidência

- Use o mesmo `Tico.app` durante toda a rodada. Uma recompilação ad hoc pode
  mudar a identidade de assinatura e fazer o macOS solicitar permissões outra
  vez.
- Não registre usuário, serial do Mac ou do trackpad, caminhos pessoais,
  conteúdo de regras, frames brutos, logs completos ou dados internos do TCC.
- Registre apenas versão do macOS, tipo geral do Mac, trackpad interno/externo,
  resultado e uma observação sanitizada.
- CI verde não altera nenhum item manual para `PASS`.

## Ambiente

| Campo | Valor |
| --- | --- |
| Data | `2026-08-13` |
| macOS | `26.5.2` |
| Build do macOS | `25F84` |
| Tipo geral do Mac | `Apple silicon` |
| Trackpad | `não exercitado nesta rodada` |
| Versão do Tico | `0.1.0 (1)` |
| Assinatura | `ad hoc`, cópia isolada com bundle identifier exclusivo da auditoria |

## Evidência automatizada da atualização

| Verificação | Status | Evidência sanitizada |
| --- | --- | --- |
| Plataforma declarada pelo SwiftPM | `PASS` | `macos 26.0` em `swift package dump-package` |
| Deployment target do executável | `PASS` | `LC_BUILD_VERSION minos 26.0`, SDK `26.5` |
| Deployment target do bundle | `PASS` | `LSMinimumSystemVersion = 26.0` |
| App Target Xcode Debug | `PASS` | bundle, identidade, versão, ícone, resources, categoria e assinatura estrita verificados |
| Archive Xcode Release | `PASS` | universal `arm64` + `x86_64`, `minos 26.0` e Hardened Runtime |
| Runtime isolado do host Xcode | `PASS` | processo abriu janela `Visão geral` com bundle e home temporários |
| Build, suíte e regressões de segurança | `PASS` | 125 testes e 8 regressões de segurança, zero falhas |
| ZIP e DMG ad hoc | `PASS` | assinatura estrita, Info.plist e DMG verificados |
| Workflow do GitHub Actions da AD-011 | `PASS` | run `31729757980` no `macos-26`: macOS 26.5.2, Xcode 26.6, 125 testes, ZIP e DMG aprovados |
| Workflow do GitHub Actions da AD-012 | `PASS` | run `31741121816` no commit `7b57e4f`: gate Xcode completo aprovado em 2m36s |

A inspeção visual usou uma cópia temporária e isolada do app, sem reutilizar a
identidade, os dados ou as permissões do Tico instalado. A aparência escura foi
aplicada somente ao processo isolado, sem alterar o sistema inteiro.

## Interface no macOS 26

| ID | Cenário | Resultado esperado | Status | Observação sanitizada |
| --- | --- | --- | --- | --- |
| UI26-01 | Abrir a janela principal no tamanho padrão e no mínimo | Sidebar, detalhe e toolbar permanecem legíveis, sem sobreposição ou corte | `PASS` | Janela principal e Laboratório inspecionados; calibração agora alterna entre duas e uma coluna sem overflow |
| UI26-02 | Alternar aparência clara e escura | Texto, ícones, seleção e estados mantêm contraste | `PASS` | Visão geral, Ajustes e Laboratório inspecionados nas duas aparências |
| UI26-03 | Ativar Reduzir Transparência | Sidebar e superfícies continuam distinguíveis e legíveis | `NOT-RUN` | — |
| UI26-04 | Ativar Reduzir Movimento e Aumentar Contraste | Fluxos continuam utilizáveis sem depender apenas de animação ou cor | `NOT-RUN` | — |
| UI26-05 | Abrir Ajustes com `⌘,` e alternar Geral/Segurança | Abas, formulários e mensagens não cortam nem deslocam controles | `PASS` | `⌘,`, Geral e Segurança inspecionados sem corte |
| UI26-06 | Abrir e usar o item da barra de menus | Ícone adapta-se ao tema e as ações continuam acessíveis | `PASS` | Item template e menu com ações legíveis foram abertos na cópia isolada |
| UI26-07 | Navegar por teclado e VoiceOver pelos fluxos principais | Foco, rótulos e ordem de leitura permanecem coerentes | `NOT-RUN` | — |

## TCC e captura global

Execute mudanças de permissão somente pela interface do Tico e pelos Ajustes do
Sistema. Não automatize `tccutil reset` nesta matriz.

| ID | Cenário | Resultado esperado | Status | Observação sanitizada |
| --- | --- | --- | --- | --- |
| TCC26-01 | Abrir o app sem Monitoramento de Entrada nem Acessibilidade | A tela mostra o estado real e o app permanece utilizável | `PASS` | Cópia isolada mostrou Acessibilidade pendente e Monitoramento de Entrada negado; navegação permaneceu utilizável |
| TCC26-02 | Tentar iniciar captura com ambas as permissões negadas | A captura não inicia e o motivo é apresentado | `PASS` | Captura permaneceu pausada e a tela de permissões apresentou os dois requisitos |
| TCC26-03 | Solicitar Monitoramento de Entrada e concluir a autorização | Após o relançamento exigido pelo sistema, o estado aparece como concedido | `NOT-RUN` | — |
| TCC26-04 | Abrir os painéis de Monitoramento de Entrada e Acessibilidade | Cada ação abre o painel correto nos Ajustes do Sistema | `NOT-RUN` | — |
| TCC26-05 | Revogar uma permissão concedida e atualizar o estado no Tico | O estado é atualizado e uma nova captura não usa autorização revogada | `NOT-RUN` | — |
| TCC26-06 | Usar teclado e mouse enquanto a captura está ativa | Eventos continuam chegando ao aplicativo de destino, sem supressão inesperada | `NOT-RUN` | — |
| TCC26-07 | Substituir o app por uma nova build ad hoc | Se o macOS pedir permissão novamente, o Tico explica o estado sem crash ou falso `PASS` | `NOT-RUN` | — |

## Trackpad no macOS 26

Abra o Laboratório com `⌘6`. A captura avançada depende do framework privado
`MultitouchSupport`; indisponibilidade deve produzir fallback público
identificável, não sucesso silencioso.

| ID | Cenário | Resultado esperado | Status | Observação sanitizada |
| --- | --- | --- | --- | --- |
| TP26-01 | Iniciar captura com trackpad interno | O modo informa `Global avançada` e recebe contatos, ou explica o fallback | `NOT-RUN` | — |
| TP26-02 | Executar tap e hold | Gestos reconhecidos uma vez, sem duplicação | `NOT-RUN` | — |
| TP26-03 | Executar swipes nas quatro direções | Cada direção é identificada corretamente | `NOT-RUN` | — |
| TP26-04 | Executar pinça para dentro e para fora | Direções reconhecidas corretamente | `NOT-RUN` | — |
| TP26-05 | Executar rotação nos dois sentidos | Sentidos reconhecidos corretamente | `NOT-RUN` | — |
| TP26-06 | Colocar o Mac em repouso e acordar | A captura retorna ou cai para fallback com estado explícito, sem travar | `NOT-RUN` | — |
| TP26-07 | Ativar manualmente o fallback público | Modo informa fallback e reconhece somente swipe, pinça e rotação | `NOT-RUN` | — |
| TP26-08 | Restaurar captura avançada após o fallback | Modo avançado retorna ou a indisponibilidade permanece explicada | `NOT-RUN` | — |
| TP26-09 | Usar o Mac normalmente por pelo menos 15 minutos | Falsos positivos são contados objetivamente; nenhum valor é inferido | `NOT-RUN` | — |
| TP26-10 | Validar pressão quando o hardware expuser faixa confiável | Pressão é calibrável; caso contrário, o item permanece `NOT-RUN` | `NOT-RUN` | — |
| TP26-11 | Repetir a matriz com Magic Trackpad | Conexão, desconexão e reconexão não travam o app; sem hardware, `NOT-RUN` | `NOT-RUN` | — |

## Persistência após atualização

| ID | Cenário | Resultado esperado | Status | Observação sanitizada |
| --- | --- | --- | --- | --- |
| UP26-01 | Criar uma regra desativada, fechar e abrir o mesmo app | Regra e estado permanecem íntegros | `NOT-RUN` | — |
| UP26-02 | Atualizar para uma nova build preservando o diretório de dados | Regras, perfis e preferências continuam legíveis | `NOT-RUN` | — |
| UP26-03 | Gravar, exportar, importar e reproduzir uma sessão | Replay funciona em 0,5×, 1× e 2× sem executar ações reais | `NOT-RUN` | — |

## Fechamento

| Resultado | Quantidade |
| --- | ---: |
| `PASS` | 6 |
| `FAIL` | 0 |
| `NOT-RUN` | 22 |

Qualquer `FAIL` em TCC, captura avançada, sleep/wake ou persistência bloqueia a
declaração de compatibilidade com macOS 26. `NOT-RUN` para Magic Trackpad limita
somente a afirmação sobre hardware externo.
