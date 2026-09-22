# Tico V2

Autorização: em 16/09/2026 o usuário pediu implementar as sete ideias discutidas.
Status: sete frentes implementadas; validação PARTIAL em 16/09/2026, conforme validation.md.
Não autoriza commit, publicação, dependências ou novos testes.

## Requisitos e aceite

- V2-01 Painel contextual: abrir perto do cursor, mostrar ações do contexto, executar
  pela fronteira existente e fechar com Escape. Abrir/fechar não executa ações.
- V2-02 Mapa e prática: listar atalhos por aplicativo, permitir escolher um e praticar
  três reconhecimentos distintos sem efeitos. Cancelar restaura a captura anterior.
  A cola pode ser exibida enquanto um atalho fica pressionado.
- V2-03 Receitas: catálogo local por objetivo, demonstração do gesto, requisitos de app,
  revisão/alteração do gatilho e criação desativada. Nenhuma instalação executa ações.
- V2-04 Cenas: criar, editar, persistir e excluir sequências nomeadas de aplicativos,
  links e organização de janelas, visualizar etapas e executar/cancelar explicitamente.
  Workflows reutilizáveis são a fonte de verdade; não há outro formato de persistência.
  Perfis podem ser associados por uma regra que reutiliza o workflow da cena.
- V2-05 Explicação: mostrar por que o último evento correspondeu ou não às regras;
  refletir a avaliação real, inclusive contexto, regras inativas e sequências pendentes.
  Mostrar resultado por etapa e permitir abrir a regra. Não persistir eventos brutos.
- V2-06 Navegação: destacar atalhos, explorar, cenas e mapa; agrupar ferramentas
  avançadas mantendo destinos, atalhos de teclado e identificadores de acessibilidade.
  Menu de status dá acesso ao painel, mapa, cenas e pausa temporária.
- V2-07 Texto: parser local de frases suportadas para gesto + aplicativo + ação;
  incompletude/ambiguidade deve ser explícita. Revisar e salvar desativada, sem execução,
  chamadas externas, geração de scripts ou substituição silenciosa de intenções.

## Restrições

SwiftUI/SwiftPM/macOS 26, sem dependências novas. ObservableObject permanece.
Views recebem dados/ações; AppKit fica em serviços. Nenhuma alteração no schema v6.
UI testing, gravação, replay e prática não devem executar automações reais.
Novos testes/mocks/fixtures não serão criados conforme AGENTS.md; isso limita a prova
automatizada de critérios novos, a ser registrada honestamente na validação.
Sem promessa de suprimir gestos do macOS, restaurar qualquer layout ou suportar
hardware externo sem observação real. Configuração de cenas é explícita.

## Verificação

Build SwiftPM, suíte existente, diff check e gate completo. UAT isolado com receitas
desativadas, navegação, parser, edição/persistência de cenas e estados vazios.
Trackpad físico, foco entre apps, VoiceOver e múltiplos monitores: validação manual.
