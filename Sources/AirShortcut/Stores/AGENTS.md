# Regras para Stores

Além das regras superiores:

- Store publica estado, aplica invariantes da coleção e coordena operações; não deve concentrar codec, migração, política de path e IO detalhado.
- Coloque codificação/decodificação em codec e acesso persistente em repository injetável quando a complexidade justificar.
- Preserve escrita atômica, rollback e último estado válido em falhas.
- Migrações devem ser determinísticas, retrocompatíveis e separadas da renderização da UI.
- Importação/exportação valida limites, formato e política de segurança antes de alterar o estado publicado.
- Injete relógio, paths, file manager ou dependências equivalentes somente onde isso melhora controle real; evite abstrações genéricas.
- Não acesse `NSApplication`, apresente sheets ou monte Views dentro do store.
- Mudanças em formato, chaves, defaults ou localização de dados exigem plano de migração e aprovação explícita.
