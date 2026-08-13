# Regras para testes

Além das regras da raiz:

- Não crie novo arquivo de teste, mock ou fixture sem pedido explícito ou autorização registrada na tarefa.
- Quando autorizado a alterar testes, siga XCTest e o padrão dos arquivos existentes; nomeie pelo comportamento observado.
- Ajuste o teste existente junto da responsabilidade movida. Não teste detalhes privados apenas para “cobrir linhas”.
- Não apague, pule, reduza assertions ou aumente tolerâncias sem justificar a mudança de contrato.
- Use diretórios temporários e defaults isolados; nunca leia dados reais do usuário, credenciais, sessões, TCC ou hardware como fixture.
- Replay deve continuar determinístico e incapaz de disparar ações reais.
- Teste automatizado não comprova hardware físico, permissões, sleep/wake, assinatura ou notarização; registre esses limites.
- Se uma nova fronteira exigir cobertura que não caiba nos arquivos atuais, pare e peça autorização antes de criar o arquivo.
