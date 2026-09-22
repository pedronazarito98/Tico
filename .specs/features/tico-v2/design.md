# Design da V2

- ShortcutStore continua como owner de regras/perfis/workflows. Cenas apresentam
  reusableWorkflows existentes; exclusão afeta a biblioteca, não cópias nas regras.
- AutomationCoordinator publica explicação efêmera e relatório da última execução;
  execução manual usa o mesmo WorkflowExecutor e a mesma aprovação de scripts.
- GesturePracticeSession conta reconhecimento sem IO, usando TriggerSequenceRuntime.
  AppController suspende execução durante gravação/prática e cancela tarefas pendentes.
- AutomationRecipeCatalog e AutomationDraftParser são funções locais de domínio.
  Receitas/texto produzem ShortcutRule desativada para revisão no editor existente.
- ContextualPanelService possui NSPanel e monitores temporários de clique. Teclado
  normalizado chega pelo capturador existente. SwiftUI compõe seu conteúdo;
  CompanionCoordinator conserva o contexto e fixa os alvos antes da execução.
  Monitores são removidos ao fechar. Eventos ficam em memória; não há histórico novo.
- ContentView permanece composition root de navegação e apresentação, com telas
  específicas para explorar, mapa, cenas e descrição. Acessibilidade existente persiste.
  O consumo de comandos publicados é agendado no próximo ciclo da main RunLoop:
  @Published emite antes de concluir a atribuição e consume verifica o envelope atual.
- Suspensão de efeitos deriva de gravação/prática/replay. Sessões de prática têm
  token de ownership; outra janela não pode encerrar a sessão adquirida pela primeira.
- Paralelo com React: stores equivalem aproximadamente a estado compartilhado;
  sessões de edição são estado local, views recebem valores e callbacks. NSPanel e
  captura global não têm equivalente direto no navegador.

## Migração

Nenhuma: schema de regras v6, caminhos, defaults e modelos persistidos permanecem.
Cenas reutilizam workflows já persistidos. As chaves antigas de navegação permanecem.
