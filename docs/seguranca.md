# Segurança do Tico

## Situação atual

O scan de 25/07/2026 encontrou 27 achados no snapshot inicial: 3 médios e
24 baixos. Todos foram corrigidos. A validação integrada mais recente executou
111 testes, incluindo 8 regressões específicas de segurança, sem falhas.

Não foram encontradas credenciais, tokens, chaves privadas ou caminhos
pessoais entre os arquivos preparados para publicação.

## Controles implementados

- Importações possuem limites de tamanho, coleções, textos e números.
- Documentos inválidos são rejeitados antes de persistir ou executar ações.
- Regras importadas entram desativadas.
- URLs aceitam somente HTTP e HTTPS.
- Shell e AppleScript exigem aprovação vinculada ao conteúdo exato.
- Replay limita frames e contatos e nunca executa regras.
- A captura privada verifica permissões e drena callbacks antes de encerrar.
- CSV neutraliza valores interpretáveis como fórmulas.
- O empacotamento usa diretório temporário privado e verifica a assinatura.

## Riscos residuais

`MultitouchSupport` é privado e não documentado. Atualizações do macOS podem
exigir manutenção e nova validação física. O fallback público reduz esse risco,
mas possui menos capacidades.

A assinatura ad hoc serve apenas para desenvolvimento. Distribuição pública
continua dependente dos gates descritos em [distribuicao.md](distribuicao.md).

Para relatar uma vulnerabilidade, siga a política em
[SECURITY.md](../SECURITY.md).
