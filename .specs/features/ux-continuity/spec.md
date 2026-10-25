# UX contínua — implementação aprovada

Pedido de 20/10/2026: implementar as propostas da auditoria, com agentes, começando por comportamento e criador unificado. Referência: `outputs/ux-audit-2026-10-20/relatorio.md`.

## Contratos

- Criar/editar usa um único `RuleEditingSession`; parâmetros essenciais ficam no contexto da escolha. Todas as ações, sequências, condições e acionamentos avançados continuam alcançáveis.
- Ensaio confirma reconhecimento, nunca sucesso de efeitos reais.
- Preferência de lembretes não bloqueia progresso. Reinício local preserva outros objetivos/conclusões.
- Painel de conteúdo oferece receitas manuais e configuração no próprio painel; navegar pelo editor não apaga a entrada. Fechar/expirar/cancelar mantém os limites de segurança existentes.
- Receitas reutilizáveis de conteúdo guardam somente configuração em sidecar próprio, sem conteúdo, paths de entrada ou seleção. Regras e schema existentes não são migrados nem substituídos. Ausência do sidecar representa coleção vazia; corrupção preserva arquivo e bloqueia sobrescrita. Escrita atômica, limites e rollback seguem os repositórios existentes.
- Rotinas começam sem cena arbitrária ou derivadas explicitamente de uma cena. O modo mostrado corresponde à elegibilidade real; salvar pausada e ativar são decisões distintas.
- Revisão humana de layout tem prazo próprio, separado do orçamento de efeitos. Expiração libera reserva e handles; retomada explícita reconsulta alvos e não repete ações anteriores.
- Cenas começam pela intenção, editam posições visualmente e conservam precisão, escolha de janela e política de monitor ausente em opções.
- Toolbar, busca e ação principal acompanham a seção. Modelos e ferramentas avançadas permanecem disponíveis.

## Integração

Três worktrees isolados, atualizados com o snapshot do checkout antes da implementação:

1. `tico-content-actions`: criador, catálogo e acionamento.
2. `tico-scene-layouts`: conteúdo, receitas e sessão.
3. `tico-learning-routines`: aprendizado e rotinas.

Raiz: cenas, reserva/revisão, shell e integração serial. Cada agente devolve manifesto de arquivos; cópia somente desses arquivos, verificando conflitos com o baseline. Sem commit, push, dependências ou novos testes/mocks/fixtures.

## Verificação

Build incremental por frente. Após integração: `git diff --check`, `swift build --disable-sandbox --product Tico`, suíte existente, gate `TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package` e inspeção interativa em dados isolados. Não usar ações reais em replay/testes.

Separar evidência de compilação, suíte e UI isolada de trackpad físico, TCC, monitor externo, VoiceOver, sleep/wake e distribuição assinada. Registrar resultado final em `validation.md`.
