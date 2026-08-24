# Changelog

## Unreleased — technical preview open source

Baseline histórica desta iniciativa: `27e0650`. Consolidação inicial integrada
em `87f65ef`. O estado atual deve ser confirmado pelo HEAD do PR de prontidão
local e seu workflow `macOS verification`.

### Prontidão local sem Developer ID

- separa desenvolvimento/beta interna de uma futura distribuição binária
  pública;
- relê permissões ao abrir, retomar e atualizar a interface;
- encerra captura, observação e automação quando a autorização é revogada;
- troca ações bloqueadas da toolbar e da barra de menus por navegação para
  Permissões;
- simula concessão e revogação somente no diretório temporário do XCUITest;
- amplia a cobertura E2E sem solicitar TCC nem executar regras reais;
- valida no CI que as 31 linhas da matriz manual usam estados válidos e que
  suas contagens coincidem com o resumo;
- cancela workflows obsoletos do mesmo PR quando um novo HEAD é enviado;
- documenta uma sessão física reproduzível usando um único artefato ad hoc.

### Incluído anteriormente

- identidade pública Tico com ícone, wordmark, menu bar e compatibilidade
  preservada para executável, bundle identifier, dados e permissões do Tico;
- gate macOS compartilhado para build, testes Swift, regressões de segurança,
  XCUITest e verificação do package ad hoc;
- licença MIT adicionada e CI remoto confirmado;
- documentação pública de status, segurança, captura privada, fallback público
  e replay isolado;
- pacote sanitizado para evidência física e validador de relatório;
- preflight que extrai o ZIP em diretório temporário e executa
  `codesign --verify --deep --strict`;
- templates e checklists de evidência para uma futura distribuição Developer
  ID.

### Estado verificado e limites

- Build/test/package do HEAD: usar o workflow do PR como fonte de verdade.
- Replay 0,5×, 1× e 2× sem execução de ações: coberto automaticamente.
- Permissões simuladas no XCUITest: não equivalem a TCC real.
- Trackpad interno: validações históricas existem; a rodada atual ainda precisa
  exercitar os cenários físicos `NOT-RUN` sobre um único artefato.
- Magic Trackpad e reconexão de hardware externo: `NOT-RUN` por falta de
  dispositivo.
- Pressão/Force Touch: suporte condicional à capacidade observada no hardware.
- Assinatura do ZIP local: ad hoc/development.
- Developer ID, notarização, staple, Gatekeeper e máquina limpa: fora do gate
  local e necessários somente para distribuição binária pública.
- Licença open source: MIT.

### Limitações

- A captura avançada usa o framework privado `MultitouchSupport` e deve ser
  revalidada por versão do macOS e classe de dispositivo.
- O fallback público tem capacidades diferentes da captura privada.
- O ZIP ad hoc serve para desenvolvimento e QA local; não deve ser apresentado
  como release pública notarizada.
- A publicação do código como technical preview open source não representa
  suporte físico nem aprovação de distribuição binária.

### Como verificar

```bash
TICO_DISABLE_SWIFTPM_SANDBOX=1 ./script/ci_verify.sh --package
./script/release_preflight.sh dist/Tico.zip
./script/validate_hardware_report.sh outputs/hardware-validation/report-AAAA-MM-DD.md
```

Consulte `outputs/roadmap.md` para o estado atual, `outputs/qa-checklist.md`
para a sessão manual e `outputs/distribuicao.md` para os gates de uma futura
release binária pública.
