# Trackpad: capacidades e limites

## Como funciona

O Tico usa o framework privado `MultitouchSupport` para observar contatos
globais do trackpad. Isso permite reconhecer taps, hold, swipes, pinça,
rotação, TipTap e gestos personalizados.

Quando essa integração não está disponível, o app usa o fallback público do
AppKit. O fallback mantém os gestos suportados pelo macOS, mas não oferece a
mesma informação de pressão, contatos individuais ou fases contínuas.

A captura é observacional: o Tico não bloqueia o gesto original do sistema.

## Estado da validação

- O uso no trackpad interno/nativo foi validado manualmente pelo responsável
  pelo produto.
- O gate automatizado cobre build, testes, regressões de segurança, replay e
  pacote local. Ele não substitui uma observação física, mas não é preciso
  manter um relatório manual para declarar o estado atual do trackpad interno.
- O [modelo de relatório](hardware-validation/report-template.md) é opcional
  e serve para investigar uma regressão ou registrar uma combinação específica
  de macOS e dispositivo.
- Pressão/Force Touch só pode ser declarada quando o hardware expõe uma faixa
  confiável e calibrável.
- Magic Trackpad e outros dispositivos externos continuam **não validados**,
  porque não havia hardware disponível.

O Tico pode ser apresentado como testado no trackpad interno. Não deve
prometer compatibilidade com Magic Trackpad.

## Quando reabrir a validação

Repetir a matriz quando houver:

- nova versão do macOS;
- mudança na ponte `MultitouchSupport`;
- Magic Trackpad ou outro dispositivo externo disponível;
- alteração no ciclo de sleep/wake, fallback ou reconexão.

O registro deve conter somente a versão do macOS, classe do dispositivo, modo
de captura e observações objetivas. Nunca incluir identificadores pessoais,
frames brutos, caminhos locais ou dados do TCC.
