# Regras para Views

Além das regras superiores:

- O `body` descreve composição e layout. Mova transições, validação, parsing, IO e orquestração para o owner apropriado.
- Extraia subviews dedicadas quando uma região tiver responsabilidade, estado ou ações próprias; evite grandes blocos computados sem contrato.
- Subviews recebem somente valores, `Binding` e closures necessários. Não passe controller/store completo por conveniência.
- O estado é criado no menor owner que precisa sobreviver ao ciclo de vida correto. Não copie estado observado para `@State` sem sincronização explícita.
- Mantenha identidade estável em listas e navegação. Não use índice como identidade de domínio.
- Preserve hierarchy, foco, atalhos, acessibilidade, estados vazios, erros contextuais e light/dark mode.
- Use tokens e componentes visuais existentes; não introduza estilos paralelos durante refatoração.
- AppKit, persistência, eventos globais e execução de regras não pertencem à view. Exponha ações estreitas.
- Para refatorações SwiftUI relevantes, siga `build-macos-apps:view-refactor` e valide estados contínuos manualmente; screenshot isolado não prova interação.
