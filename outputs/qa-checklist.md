# Checklist de QA do Tico

Use `PASS`, `FAIL` ou `NOT-RUN`. Um item não executado nunca equivale a
aprovação.

## Gate automatizado

```sh
./script/ci_verify.sh --package
```

Confirmar:

- build SwiftPM e suíte completa sem falhas;
- regressões de segurança sem falhas;
- `dist/Tico.zip` contém `Tico.app`;
- app extraído passa `codesign --verify --deep --strict`;
- nome público é Tico, executável é Tico e bundle identifier permanece
  `com.pedronazarito.Tico`.

## Permissões e entradas

- Janela principal abre e volta ao primeiro plano.
- Monitoramento de Entrada e Acessibilidade mostram o estado real.
- Com permissão negada, a captura não inicia e explica o motivo.
- Teclado e mouse continuam chegando ao aplicativo original.
- Uma regra importada entra desativada.

## Trackpad interno

Abrir o Laboratório com `⌘6` e validar:

- captura avançada identificada corretamente;
- tap e hold;
- swipes nas quatro direções;
- pinça para dentro e para fora;
- rotação nos dois sentidos;
- recuperação após sleep/wake;
- fallback público e segurança de teclado/mouse;
- período de uso normal com contagem objetiva de falsos positivos;
- pressão somente quando houver faixa confiável e calibrável.

Se for necessário investigar uma regressão, registre o resultado sanitizado
em uma cópia de [report-template.md](hardware-validation/report-template.md).
Isso é opcional e não bloqueia o gate automatizado.

## Hardware externo

Sem Magic Trackpad disponível, marcar como `NOT-RUN`. Não declarar
compatibilidade.

Quando houver hardware:

1. Conecte o Magic Trackpad por Bluetooth e confirme que aparece no macOS.
2. Abra o Tico, inicie a captura e abra o Laboratório com `⌘6`.
3. Execute tap, hold, os quatro swipes, pinça, rotação e o fallback público.
4. Desconecte e reconecte o dispositivo; confirme que a captura retorna ou
   que o app explica o estado sem travar.
5. Rode um período curto de uso normal e observe falsos positivos.

Se algum cenário falhar, não declare compatibilidade. Para registrar o caso,
use o relatório opcional sem número de série, usuário, caminhos ou frames
brutos.

## Replay, regras e interface

- Gravar, exportar e importar uma sessão.
- Reproduzir em 0,5×, 1× e 2× sem executar ações.
- Criar, salvar, desativar, ativar e excluir uma regra.
- Validar ação inválida e cancelamento de shell/AppleScript sem crash.
- Verificar modos claro/escuro, navegação por teclado e barra de menus.
- Confirmar que regras, preferências e permissões sobrevivem à atualização.

## Release pública

Além dos itens anteriores:

- Developer ID Application;
- Hardened Runtime e assinatura aninhada;
- notarização aceita;
- `stapler validate`;
- Gatekeeper aceito;
- execução do mesmo ZIP em Mac ou usuário limpo.
