# Checklist de QA do Tico

Use `PASS`, `FAIL` ou `NOT-RUN`. Um item não executado nunca equivale a
aprovação.

Para validar especificamente a atualização do sistema, use também a
[matriz manual de macOS 26, trackpad e TCC](macos-26-manual-matrix.md). Ela
mantém interface, permissões e hardware separados dos gates automatizados.

## Escopo desta prontidão

O gate atual prepara o Tico para desenvolvimento, uso local e beta interna
controlada. Developer ID, notarização, staple e Gatekeeper não bloqueiam esse
escopo; eles só voltam a ser obrigatórios caso exista intenção de distribuir
um binário público para outras pessoas.

Trackpad físico, TCC real, sleep/wake, VoiceOver e hardware externo continuam
exigindo evidência manual, independentemente do CI.

## Gate automatizado

```sh
TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package
```

Confirmar:

- builds SwiftPM e do App Target Xcode sem falhas;
- `Tico.app` do Xcode preserva versão, bundle identifier, ícone, resources,
  assinatura ad hoc estrita e deployment target `26.0`;
- XCUITest roda com home, dados, preferências e permissões simuladas isoladas;
- regressões de segurança sem falhas;
- contagens da matriz manual coincidem com seu resumo;
- `dist/Tico.zip` contém `Tico.app`;
- app extraído passa `codesign --verify --deep --strict`;
- nome público é Tico, executável é Tico e bundle identifier permanece
  `com.pedronazarito.Tico`.

O XCUITest pode simular concessão e revogação para validar a interface, mas não
modifica nem comprova o TCC do macOS.

## Sessão manual com um único artefato

Use esta sequência para evitar que uma recompilação ad hoc altere a identidade
observada pelo macOS durante a rodada:

1. Feche qualquer cópia do Tico usada anteriormente.
2. Execute o gate completo uma única vez:

   ```sh
   TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package
   ```

3. Registre um hash sanitizado do arquivo, sem caminhos pessoais:

   ```sh
   shasum -a 256 dist/Tico.zip
   ```

4. Extraia `dist/Tico.zip` para uma pasta temporária de QA.
5. Use exatamente o mesmo `Tico.app` em todos os cenários da matriz.
6. Não recompile, não substitua o bundle e não execute `tccutil reset` durante
   a sessão.
7. Atualize somente os itens realmente exercitados. Um resultado simulado ou
   automatizado não muda um cenário físico para `PASS`.
8. Ao terminar, encerre a captura e o aplicativo.

Registre apenas versão do macOS, tipo geral do Mac, trackpad interno/externo,
hash do artefato, resultado e observação sanitizada. Não registre usuário,
serial, caminhos pessoais, conteúdo de regras, frames brutos ou dados internos
do TCC.

## Permissões e entradas

- Janela principal abre e volta ao primeiro plano.
- Monitoramento de Entrada e Acessibilidade mostram o estado real.
- Toolbar, Overview e barra de menus direcionam para Permissões quando o acesso
  ainda não está disponível.
- Com permissão negada, a captura não inicia e explica o motivo.
- Revogar uma permissão encerra captura e observação depois que o app volta ao
  primeiro plano ou os estados são atualizados.
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
- Verificar modos claro/escuro, Reduzir Transparência, Reduzir Movimento,
  Aumentar Contraste, navegação por teclado e VoiceOver.
- Confirmar que regras e preferências sobrevivem à atualização.
- Confirmar que o estado de permissões é relido após voltar ao primeiro plano.

## Distribuição binária pública — fora do escopo atual

Somente quando houver intenção de distribuir um binário público:

- Developer ID Application;
- Hardened Runtime e assinatura aninhada;
- notarização aceita;
- `stapler validate`;
- Gatekeeper aceito;
- execução do mesmo ZIP em Mac ou usuário limpo.
