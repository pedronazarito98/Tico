# Evidências de validação de hardware

Esta pasta guarda modelos e fixtures sanitizadas. Um relatório é opcional: ele
comprova somente a versão do macOS e a classe de dispositivo realmente
testadas, quando for útil investigar uma regressão física.

## Como registrar (opcional)

1. Copie `report-template.md` para `outputs/report-AAAA-MM-DD.md` a partir da
   raiz do repositório. Crie `outputs/` se necessário; os relatórios locais são
   ignorados pelo Git.
2. Preencha uma linha por cenário observado.
3. Use somente `PASS`, `FAIL` ou `NOT-RUN`.
4. Execute:

   ```sh
   ./script/validate_hardware_report.sh outputs/report-AAAA-MM-DD.md
   ```

Os nomes técnicos das colunas e os valores de classe permanecem em inglês
porque fazem parte do contrato do validador.

Classes permitidas:

- `internal`
- `magic-trackpad`
- `other`
- `unknown`

Modos permitidos:

- `advanced-private`
- `public-fallback`
- `unavailable`

## Nunca registrar

- número de série, nome do computador ou usuário;
- dump ou identificador do TCC;
- frames brutos, coordenadas ou sessões pessoais;
- logs com aplicativos, arquivos ou caminhos pessoais.
