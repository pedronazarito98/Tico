# Regras para `Sources/AirShortcut`

Além das regras da raiz:

- Mantenha uma responsabilidade principal por tipo e um tipo principal por arquivo, salvo extensões privadas muito locais.
- Antes de ampliar um arquivo concentrador, procure extrair estado, efeito ou componente pelo boundary mais estreito.
- Trate arquivos acima de aproximadamente 400 linhas como sinal para revisão de responsabilidades, não como falha automática nem meta mecânica.
- Dependências são construídas no composition root e passadas explicitamente; não crie singleton global ou service locator.
- Domínio puro não importa SwiftUI/AppKit e não acessa arquivo, processo, evento global ou bridge C.
- Efeitos de plataforma ficam atrás de protocolos pequenos quando existir necessidade real de substituição, isolamento ou teste.
- Preserve APIs compatíveis durante migrações e remova fachadas somente depois que todos os consumidores forem migrados e validados.
- Não use `Support` como pasta genérica. Fronteiras compartilhadas e tipos de coordenação podem permanecer ali quando o owner estiver explícito; coloque cada outro tipo junto do owner da responsabilidade.

## Estado SwiftUI

- O owner de um objeto de longa duração o cria com `@StateObject`; filhos usam `@ObservedObject` ou projeções explícitas.
- Use `@State` para estado efêmero local, `@SceneStorage` para estado por janela e `@AppStorage` somente para preferências simples.
- Não mantenha duas fontes de verdade para a mesma regra, captura, seleção ou automação.
- Prefira valores, `Binding` e closures a passar `AppController`/stores inteiros quando a view usa uma projeção pequena.
